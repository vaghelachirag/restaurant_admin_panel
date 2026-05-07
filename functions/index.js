const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

const {
  onRequest,
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");

const admin = require("firebase-admin");
const axios = require("axios");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const cors = require("cors")({ origin: true });

admin.initializeApp();

const ONE_SIGNAL_APP_ID  = "1dbbdcbd-590f-475c-88d0-7c6d953d63ca";
const ONE_SIGNAL_API_KEY = "os_v2_app_dw55zpkzb5dvzcgqprwzkpldzjzlodgpfcvezw5v7s2ko6zko4z6yvfwbx5y52j5oyr2lr6jwckmtzp3nkvd465y65difrwrk22b7ba";

// ─────────────────────────────────────────────────────────────────────────────
//  ASSIGN RESTAURANT CLAIMS
// ─────────────────────────────────────────────────────────────────────────────

exports.assignRestaurantClaim = onCall(async (request) => {
  try {
    if (!request.auth) throw new HttpsError("unauthenticated", "User not authenticated");
    const uid          = request.auth.uid;
    const restaurantId = request.data.restaurantId;
    if (!restaurantId || typeof restaurantId !== "string")
      throw new HttpsError("invalid-argument", "restaurantId is required");
    await admin.auth().setCustomUserClaims(uid, { restaurantId, role: "owner" });
    await admin.firestore().collection("users").doc(uid).set(
      { uid, restaurantId, role: "owner", updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );
    console.log(`✅ Claims assigned for UID: ${uid}`);
    return { success: true, restaurantId };
  } catch (error) {
    console.error("❌ assignRestaurantClaim ERROR:", error);
    throw new HttpsError("internal", error.message || "Something went wrong");
  }
});

exports.syncUserClaims = onCall(async (request) => {
  try {
    if (!request.auth) throw new HttpsError("unauthenticated", "User must be signed in");
    const uid       = request.auth.uid;
    const accessDoc = await admin.firestore().collection("user_access").doc(uid).get();
    if (!accessDoc.exists)
      throw new HttpsError("not-found", `No user_access document found for uid: ${uid}.`);
    const { role, restaurantId, managerId } = accessDoc.data();
    if (!role) throw new HttpsError("failed-precondition", "user_access document missing 'role'");
    const claims = { role };
    if (restaurantId) claims.restaurantId = restaurantId;
    if (managerId)    claims.managerId    = managerId;
    await admin.auth().setCustomUserClaims(uid, claims);
    console.log(`✅ syncUserClaims: uid=${uid} role=${role}`);
    return { success: true, role, restaurantId: restaurantId ?? null };
  } catch (error) {
    console.error("❌ syncUserClaims ERROR:", error.message);
    throw new HttpsError("internal", error.message || "Failed to sync claims");
  }
});

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED HELPERS  (OneSignal notifications)
// ─────────────────────────────────────────────────────────────────────────────

const SOUND_CONFIG = {
  new_order:   { ios_sound: "new_order.caf"   },
  waiter_call: { ios_sound: "waiter_call.caf" },
};

async function sendOneSignalNotification(playerId, heading, body, data = {}, sound = "new_order") {
  const cfg     = SOUND_CONFIG[sound] ?? SOUND_CONFIG["new_order"];
  const payload = {
    app_id:              ONE_SIGNAL_APP_ID,
    include_player_ids:  [playerId],
    headings:            { en: heading },
    contents:            { en: body },
    android_sound:       sound,
    ios_sound:           cfg.ios_sound,
    priority:            10,
    android_visibility:  1,
    android_badge_type:  "Increase",
    android_badge_count: 1,
    small_icon:          "ic_stat_onesignal_default",
    large_icon:          "ic_launcher",
    data,
  };
  return axios.post("https://onesignal.com/api/v1/notifications", payload, {
    headers: { "Content-Type": "application/json", Authorization: `Basic ${ONE_SIGNAL_API_KEY}` },
  });
}

async function getManagerPlayerIds(db, restaurantId) {
  const snap = await db.collection("restaurants").doc(restaurantId).collection("managers").get();
  const ids  = [];
  snap.forEach((doc) => {
    const pid = doc.data()?.onesignalPlayerId;
    if (pid && pid.trim() !== "") ids.push(pid.trim());
  });
  return ids;
}

async function getAllRecipientPlayerIds(db, restaurantId) {
  const [restaurantDoc, managerIds] = await Promise.all([
    db.collection("restaurants").doc(restaurantId).get(),
    getManagerPlayerIds(db, restaurantId),
  ]);
  const ownerPlayerId = restaurantDoc.data()?.onesignalPlayerId;
  const all           = ownerPlayerId ? [ownerPlayerId, ...managerIds] : [...managerIds];
  return [...new Set(all)];
}

async function fanOut(playerIds, heading, body, data = {}, sound = "new_order") {
  const results = await Promise.allSettled(
    playerIds.map((pid) => sendOneSignalNotification(pid, heading, body, data, sound))
  );
  results.forEach((r, i) => {
    if (r.status === "fulfilled") console.log(`✅ Sent to playerIds[${i}]`);
    else console.error(`❌ Failed for playerIds[${i}]:`, r.reason?.message);
  });
}

function buildTableLabel(order) {
  if (order.orderType === "Parcel") return "Parcel 📦";
  return order.tableName || order.tableId || "Dine In";
}

// ─────────────────────────────────────────────────────────────────────────────
//  NEW ORDER NOTIFICATION
// ─────────────────────────────────────────────────────────────────────────────

exports.sendNewOrderNotification = onDocumentCreated(
  "restaurants/{restaurantId}/orders/{orderId}",
  async (event) => {
    try {
      const order        = event.data.data();
      const restaurantId = event.params.restaurantId;
      const orderId      = event.params.orderId;
      const db           = admin.firestore();
      const playerIds    = await getAllRecipientPlayerIds(db, restaurantId);
      if (playerIds.length === 0) return;
      const tableLabel = buildTableLabel(order);
      const itemCount  = (order.items || []).length;
      const amount     = (order.totalAmount || 0).toFixed(2);
      await fanOut(playerIds,
        `New Order — ${tableLabel}`,
        `${itemCount} item${itemCount !== 1 ? "s" : ""} • ₹${amount}`,
        { type: "new_order", orderId, restaurantId,
          tableId: order.tableId || "", tableName: order.tableName || "" },
        "new_order"
      );
    } catch (error) {
      console.error("❌ sendNewOrderNotification ERROR:", error.message);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
//  ASSISTANCE REQUEST NOTIFICATIONS
// ─────────────────────────────────────────────────────────────────────────────

const REQUEST_TYPE_LABELS = {
  call_waiter: "Call Waiter 🔔",
  water:       "Water 💧",
  order:       "Order 🧾",
  bill:        "Bill 💳",
};

exports.sendAssistanceRequestNotification = onDocumentCreated(
  "restaurants/{restaurantId}/assistance_requests/{requestId}",
  async (event) => {
    try {
      const request      = event.data.data();
      const restaurantId = event.params.restaurantId;
      const requestId    = event.params.requestId;
      const db           = admin.firestore();
      const playerIds    = await getAllRecipientPlayerIds(db, restaurantId);
      if (playerIds.length === 0) return;
      const typeKey    = request.type || "call_waiter";
      const typeLabel  = REQUEST_TYPE_LABELS[typeKey] || typeKey;
      const tableLabel = request.tableName || request.tableId || "Unknown Table";
      const note       = (request.note || "").trim();
      await fanOut(playerIds,
        `Assistance Needed — ${tableLabel}`,
        note ? `${typeLabel} • "${note}"` : typeLabel,
        { type: "assistance_request", requestId, restaurantId,
          requestType: typeKey, tableId: request.tableId || "",
          tableName: request.tableName || "" },
        "waiter_call"
      );
    } catch (error) {
      console.error("❌ sendAssistanceRequestNotification ERROR:", error.message);
    }
  }
);

exports.sendAssistanceStatusNotification = onDocumentUpdated(
  "restaurants/{restaurantId}/assistance_requests/{requestId}",
  async (event) => {
    try {
      const before = event.data.before.data();
      const after  = event.data.after.data();
      if (before.status === after.status) return;
      const validTransitions = {
        pending: "acknowledged", acknowledged: "on_the_way", on_the_way: "completed",
      };
      if (validTransitions[before.status] !== after.status) return;
      const restaurantId = event.params.restaurantId;
      const requestId    = event.params.requestId;
      const db           = admin.firestore();
      const playerIds    = await getAllRecipientPlayerIds(db, restaurantId);
      if (playerIds.length === 0) return;
      const typeKey      = after.type || "call_waiter";
      const typeLabel    = REQUEST_TYPE_LABELS[typeKey] || typeKey;
      const tableLabel   = after.tableName || after.tableId || "Unknown Table";
      const statusLabels = {
        acknowledged: "Acknowledged ✅", on_the_way: "Waiter On the Way 🚶", completed: "Completed 🎉",
      };
      await fanOut(playerIds,
        `Request ${statusLabels[after.status] || after.status} — ${tableLabel}`,
        `${typeLabel} has been marked as "${after.status}"`,
        { type: "assistance_status_update", requestId, restaurantId,
          requestType: typeKey, status: after.status,
          tableId: after.tableId || "", tableName: after.tableName || "" },
        "waiter_call"
      );
    } catch (error) {
      console.error("❌ sendAssistanceStatusNotification ERROR:", error.message);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
//  MENU IMAGE → CSV  (Gemini OCR)
// ─────────────────────────────────────────────────────────────────────────────

const GEMINI_MODEL = "gemini-1.5-flash";
const OCR_PROMPT   = `You are an expert at reading Indian restaurant menu images and extracting structured data.\n\nReturn ONLY JSON array.`;

function escapeCsv(value) {
  const str = String(value);
  if (str.includes(",") || str.includes('"') || str.includes("\n")) return `"${str.replace(/"/g, '""')}"`;
  return str;
}

exports.menuImageToCsv = onRequest(
  { timeoutSeconds: 60, memory: "512MiB", secrets: ["GEMINI_API_KEY"] },
  async (req, res) => {
    cors(req, res, async () => {
      if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });
      const { image, mimeType = "image/jpeg" } = req.body;
      if (!image) return res.status(400).json({ error: "No image data provided." });
      try {
        const genAI  = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
        const model  = genAI.getGenerativeModel({ model: GEMINI_MODEL });
        const result = await model.generateContent([
          { text: OCR_PROMPT }, { inlineData: { mimeType, data: image } },
        ]);
        const rawText = result.response.text().trim();
        let parsed;
        try {
          const cleaned = rawText.replace(/^```json\s*/i,"").replace(/^```\s*/i,"").replace(/```\s*$/i,"").trim();
          const start   = cleaned.indexOf("[");
          const end     = cleaned.lastIndexOf("]");
          if (start === -1 || end === -1) throw new Error("No JSON array found");
          parsed = JSON.parse(cleaned.substring(start, end + 1));
        } catch (e) {
          return res.status(500).json({ error: "Could not read the menu structure." });
        }
        if (!Array.isArray(parsed)) return res.status(500).json({ error: "Unexpected AI response format." });
        const seen = new Set(), csvRows = [], items = [];
        for (const item of parsed) {
          const name = String(item.name || "").trim(), category = String(item.category || "").trim();
          if (!name || !category) continue;
          const validVariants = [];
          for (const v of (Array.isArray(item.variants) ? item.variants : [])) {
            const vName = String(v.name || "").trim(), vPrice = Number(v.price);
            if (!vName || isNaN(vPrice) || vPrice <= 0) continue;
            const key = `${name}||${category}||${vName}`;
            if (seen.has(key)) continue;
            seen.add(key);
            validVariants.push({ name: vName, price: vPrice });
            csvRows.push(`${escapeCsv(name)},${escapeCsv(category)},${escapeCsv(vName)},${vPrice.toFixed(2)}`);
          }
          if (validVariants.length === 0) continue;
          items.push({ name, category, variants: validVariants });
        }
        return res.status(200).json({ items, csv: ["name,category,variant_name,price", ...csvRows].join("\n") });
      } catch (err) {
        return res.status(500).json({ error: "An unexpected error occurred." });
      }
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
//  CUSTOMER ORDER STATUS NOTIFICATION  — FCM Web Push
//
//  WHY 2 NOTIFICATIONS WERE APPEARING:
//
//  Previous payload had top-level `notification` field:
//    { notification: { title, body }, webpush: { notification: { title, body } } }
//
//  This caused:
//   Notification 1: FCM sees `notification` field → auto-shows OS notification
//                   → tap opens `webpush.fcm_options.link = "/"` → LOGIN PAGE
//   Notification 2: SW onBackgroundMessage → shows webpush notification
//                   → tap opens order page (via notificationclick handler)
//
//  THE CORRECT FIX:
//  Remove top-level `notification` field AND `webpush.fcm_options.link`.
//  Send as DATA-ONLY message with `webpush.notification` only.
//  FCM will NOT auto-show anything. Only SW onBackgroundMessage shows it.
//  The notificationclick handler in SW handles the tap → opens order page.
//  Result: exactly 1 notification, correct tap navigation.
// ─────────────────────────────────────────────────────────────────────────────

const ORDER_STATUS_MESSAGES = {
  preparing: { title: "✅ Order Accepted!",  body: "Your order has been accepted and is being prepared."      },
  ready:     { title: "🍽️ Order Ready!",     body: "Your order is ready. It will be served to you shortly."  },
  served:    { title: "🎉 Order Served!",     body: "Your order has been served. Enjoy your meal!"            },
  completed: { title: "✔️ Order Completed",  body: "Thank you for dining with us!"                           },
  cancelled: { title: "❌ Order Cancelled",  body: "Sorry, your order has been cancelled. Please contact staff." },
};

const SILENT_STATUSES = new Set(["pending"]);

exports.notifyCustomerOnOrderStatusChange = onDocumentUpdated(
  "restaurants/{restaurantId}/orders/{orderId}",
  async (event) => {
    try {
      const before    = event.data.before.data();
      const after     = event.data.after.data();
      const oldStatus = (before.status || "").toLowerCase().trim();
      const newStatus = (after.status  || "").toLowerCase().trim();

      if (oldStatus === newStatus) return;
      if (SILENT_STATUSES.has(newStatus)) return;

      const msgConfig = ORDER_STATUS_MESSAGES[newStatus];
      if (!msgConfig) {
        console.log(`[notifyCustomer] No config for "${newStatus}" — skipping`);
        return;
      }

      console.log(`[notifyCustomer] 🔥 ${oldStatus} → ${newStatus} | order: ${event.params.orderId}`);

      const browserToken = after.browserToken;
      if (!browserToken || browserToken.trim() === "") {
        console.log("[notifyCustomer] No browserToken — skipping");
        return;
      }

      const orderId      = event.params.orderId;
      const restaurantId = event.params.restaurantId;

      // ── CORRECT PAYLOAD — data-only + webpush.notification only ──────────
      //
      // NO top-level `notification` field → FCM will NOT auto-show an OS
      // notification on Android. Only the SW `onBackgroundMessage` handler
      // will receive this and show the notification via showNotification().
      //
      // NO `webpush.fcm_options.link` → removes the second tap destination
      // that was opening the login page. The SW `notificationclick` handler
      // handles tap navigation to the correct order page.
      // ─────────────────────────────────────────────────────────────────────
      const message = {
        token: browserToken,

        // data — readable by Flutter onMessage and SW onBackgroundMessage
        data: {
          orderId,
          restaurantId,
          status: newStatus,
          type:   "order_status_update",
          title:  msgConfig.title,
          body:   msgConfig.body,
        },

        // webpush — controls what the browser shows
        webpush: {
          // notification — shown by SW onBackgroundMessage
          // NOT shown automatically by FCM because no top-level notification field
          notification: {
            title:   msgConfig.title,
            body:    msgConfig.body,
            icon:    "/icons/Icon-192.png",
            badge:   "/icons/Icon-192.png",
            vibrate: [200, 100, 200],
            // tag ensures only 1 notification per order status
            tag:     `order-${orderId}-${newStatus}`,
            // data for notificationclick handler in SW
            data: {
              orderId,
              restaurantId,
              status:  newStatus,
              // correct order page URL — tapping notification opens this
              url: `https://restaurant-menu-system-fc074.web.app/#/order/${restaurantId}/${orderId}`,
            },
          },
          // NO fcm_options.link — removed to prevent login page redirect
        },
      };

      const response = await admin.messaging().send(message);
      console.log(`[notifyCustomer] ✅ Sent. FCM response: ${response}`);

    } catch (error) {
      if (error.code === "messaging/registration-token-not-registered") {
        console.log("[notifyCustomer] Token expired — removing");
        try {
          await admin.firestore()
            .collection("restaurants").doc(event.params.restaurantId)
            .collection("orders").doc(event.params.orderId)
            .update({ browserToken: admin.firestore.FieldValue.delete() });
        } catch (e) {
          console.error("[notifyCustomer] Cleanup failed:", e.message);
        }
        return;
      }
      console.error("[notifyCustomer] ❌ Error:", error.message);
    }
  }
);