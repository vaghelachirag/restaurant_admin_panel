/**
 * kot-server.js
 * ─────────────────────────────────────────────────────────────────────────────
 * KOT thermal print server — printer config is stored in Firestore,
 * NOT hardcoded. Change printer IP from the app anytime.
 *
 * Firestore path:
 *   restaurants/{restaurantId}/settings/printer
 *   Fields:
 *     interface   : "tcp://192.168.1.50"  | "/dev/usb/lp0" | "//PC/PrinterName"
 *     type        : "EPSON" | "STAR" | "TANCA"
 *     enabled     : true
 *     name        : "Kitchen Printer"     (display label)
 *
 * SETUP:
 *   1. npm install express node-thermal-printer firebase-admin
 *   2. Download your Firebase service account JSON from:
 *      Firebase Console → Project Settings → Service Accounts → Generate new key
 *      Save it as  serviceAccountKey.json  in the same folder as this file
 *   3. node kot-server.js
 *
 * KEEP RUNNING:
 *   npm install -g pm2
 *   pm2 start kot-server.js --name kot
 *   pm2 save && pm2 startup
 */

"use strict";

const express       = require("express");
const admin         = require("firebase-admin");
const { ThermalPrinter, PrinterTypes, CharacterSet } = require("node-thermal-printer");
const path          = require("path");

// ─── Firebase init ────────────────────────────────────────────────────────────
const serviceAccount = require(path.join(__dirname, "serviceAccountKey.json"));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

const PORT = process.env.PORT || 3001;
const app  = express();
app.use(express.json());

// ─── Printer type map ─────────────────────────────────────────────────────────
const TYPE_MAP = {
  EPSON: PrinterTypes.EPSON,
  STAR:  PrinterTypes.STAR,
  TANCA: PrinterTypes.TANCA,
};

// ─── Load printer config from Firestore ───────────────────────────────────────
async function getPrinterConfig(restaurantId) {
  const snap = await db
    .collection("restaurants")
    .doc(restaurantId)
    .collection("settings")
    .doc("printer")
    .get();

  if (!snap.exists) {
    throw new Error(`No printer config found for restaurant: ${restaurantId}`);
  }

  const data = snap.data();

  if (!data.enabled) {
    throw new Error("Printer is disabled in settings");
  }

  if (!data.interface) {
    throw new Error("Printer interface not set in Firestore settings");
  }

  return {
    interface: data.interface,                         // e.g. "tcp://192.168.1.50"
    type:      TYPE_MAP[data.type] || PrinterTypes.EPSON,
    name:      data.name || "Kitchen Printer",
  };
}

// ─── Build and connect a printer instance ─────────────────────────────────────
async function createPrinter(restaurantId) {
  const config = await getPrinterConfig(restaurantId);
  console.log(`🖨️  Using printer: ${config.name} @ ${config.interface}`);

  return new ThermalPrinter({
    type:         config.type,
    interface:    config.interface,
    characterSet: CharacterSet.PC437_USA,
    removeSpecialCharacters: false,
    lineCharacter: "-",
    options: { timeout: 5000 },
  });
}

// ─── Format timestamp to IST ──────────────────────────────────────────────────
function formatIST(isoString) {
  return new Date(isoString).toLocaleString("en-IN", {
    timeZone: "Asia/Kolkata",
    hour:     "2-digit", minute:  "2-digit",
    day:      "2-digit", month:   "short",
    year:     "numeric", hour12:  true,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  POST /print-kot
//  Called automatically by Firebase Cloud Function on every new/updated order.
// ─────────────────────────────────────────────────────────────────────────────
app.post("/print-kot", async (req, res) => {
  const {
    restaurantId = "",
    orderId      = "",
    tableName    = "",
    tableId      = "",
    orderType    = "Dine In",
    tokenNumber  = "",
    customerName = "",
    mobile       = "",
    items        = [],
    totalAmount  = 0,
    timestamp    = new Date().toISOString(),
    isUpdate     = false,
  } = req.body;

  if (!restaurantId) {
    return res.status(400).json({ success: false, error: "restaurantId is required" });
  }

  console.log(`\n📥 KOT request — restaurant: ${restaurantId} | table: ${tableName || tableId} | token: ${tokenNumber}`);

  try {
    const printer = await createPrinter(restaurantId);

    // ── Header ───────────────────────────────────────────────────────────────
    printer.alignCenter();
    printer.bold(true);
    printer.setTextSize(1, 1);
    printer.println(isUpdate ? "*** ORDER UPDATED ***" : "*** KITCHEN ORDER ***");
    printer.setTextNormal();
    printer.bold(false);
    printer.drawLine();

    // ── Order info ───────────────────────────────────────────────────────────
    printer.alignLeft();
    printer.println(`Type    : ${orderType}`);
    printer.println(`Table   : ${tableName || tableId || "Dine In"}`);

    if (tokenNumber) {
      printer.bold(true);
      printer.println(`Token   : #${tokenNumber}`);
      printer.bold(false);
    }

    if (customerName) printer.println(`Customer: ${customerName}`);
    if (mobile)       printer.println(`Mobile  : ${mobile}`);
    printer.println(`Time    : ${formatIST(timestamp)}`);
    printer.drawLine();

    // ── Items ────────────────────────────────────────────────────────────────
    printer.bold(true);
    printer.println("ITEMS:");
    printer.bold(false);
    printer.newLine();

    if (items.length === 0) {
      printer.println("  (no items)");
    } else {
      for (const item of items) {
        const name    = item.name        || item.itemName     || "Unknown";
        const qty     = item.qty         || item.quantity     || item.count || 1;
        const variant = item.variant     || item.variantName  || item.size  || "";
        const note    = item.note        || item.specialNote  || item.instructions || "";
        const price   = item.price       || item.totalPrice   || 0;

        printer.bold(true);
        printer.print(`${qty}x  `);
        printer.bold(false);
        printer.println(name);

        if (variant) printer.println(`     [${variant}]`);
        if (note)    printer.println(`     > ${note}`);
        if (price)   printer.println(`     Rs. ${Number(price).toFixed(0)}`);

        printer.newLine();
      }
    }

    // ── Total + footer ───────────────────────────────────────────────────────
    printer.drawLine();
    printer.bold(true);
    printer.println(`TOTAL   : Rs. ${Number(totalAmount).toFixed(0)}`);
    printer.bold(false);
    printer.drawLine();
    printer.alignCenter();
    printer.println(`Ref: ${orderId.substring(0, 12)}`);
    printer.newLine();
    printer.newLine();
    printer.cut();

    await printer.execute();
    console.log("✅ Printed successfully");
    res.json({ success: true });

  } catch (err) {
    console.error("❌ Print error:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
//  GET /test-print?restaurantId=xxx
//  Visit from browser to verify printer is working.
// ─────────────────────────────────────────────────────────────────────────────
app.get("/test-print", async (req, res) => {
  const { restaurantId } = req.query;
  if (!restaurantId) {
    return res.status(400).json({ error: "restaurantId query param required" });
  }

  try {
    const printer = await createPrinter(restaurantId);
    printer.alignCenter();
    printer.bold(true);
    printer.println("*** PRINTER TEST ***");
    printer.bold(false);
    printer.drawLine();
    printer.println("KOT server connected!");
    printer.println(formatIST(new Date().toISOString()));
    printer.drawLine();
    printer.cut();
    await printer.execute();
    res.json({ success: true, message: "Test print sent!" });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
//  GET /health
//  Returns server status and printer config from Firestore (no test print).
// ─────────────────────────────────────────────────────────────────────────────
app.get("/health", async (req, res) => {
  const { restaurantId } = req.query;
  const result = { status: "ok", time: new Date().toISOString() };

  if (restaurantId) {
    try {
      const config = await getPrinterConfig(restaurantId);
      result.printer = { name: config.name, interface: config.interface };
    } catch (err) {
      result.printer = { error: err.message };
    }
  }

  res.json(result);
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`\n🖨️  KOT Server started`);
  console.log(`   Port   : ${PORT}`);
  console.log(`   Health : http://localhost:${PORT}/health`);
  console.log(`   Test   : http://localhost:${PORT}/test-print?restaurantId=YOUR_ID\n`);
});