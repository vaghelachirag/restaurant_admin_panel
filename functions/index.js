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
const ONE_SIGNAL_API_KEY = "os_v2_app_dw55zpkzb5dvzcgqprwzkpldzkiot3phwrsezafgrcokejddrctxmdlggmisgixlbam6mw4cuibzin4zx46lxpg57ljgvxebbhpn2ta";

// ─────────────────────────────────────────────────────────────────────────────
//  ASSIGN RESTAURANT CLAIMS
// ─────────────────────────────────────────────────────────────────────────────

exports.assignRestaurantClaim = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User not authenticated");
    }

    const uid          = request.auth.uid;
    const restaurantId = request.data.restaurantId;

    if (!restaurantId || typeof restaurantId !== "string") {
      throw new HttpsError("invalid-argument", "restaurantId is required");
    }

    await admin.auth().setCustomUserClaims(uid, {
      restaurantId,
      role: "owner",
    });

    await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .set(
        {
          uid,
          restaurantId,
          role:      "owner",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
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
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be signed in");
    }

    const uid = request.auth.uid;

    // Read role + restaurantId from user_access (source of truth for all roles)
    const accessDoc = await admin
      .firestore()
      .collection("user_access")
      .doc(uid)
      .get();

    if (!accessDoc.exists) {
      throw new HttpsError(
        "not-found",
        `No user_access document found for uid: ${uid}. ` +
        "Ask a super admin to create one."
      );
    }

    const { role, restaurantId, managerId } = accessDoc.data();

    if (!role) {
      throw new HttpsError("failed-precondition", "user_access document is missing 'role' field");
    }

    // Build claims — restaurantId and managerId are optional depending on role
    const claims = { role };
    if (restaurantId) claims.restaurantId = restaurantId;
    if (managerId)    claims.managerId    = managerId;

    await admin.auth().setCustomUserClaims(uid, claims);

    console.log(`✅ syncUserClaims: uid=${uid} role=${role} restaurantId=${restaurantId ?? "none"}`);
    return { success: true, role, restaurantId: restaurantId ?? null };

  } catch (error) {
    console.error("❌ syncUserClaims ERROR:", error.message);
    throw new HttpsError("internal", error.message || "Failed to sync claims");
  }
});


const SOUND_CONFIG = {
  new_order:   { android_channel_id: "new_order_channel",   ios_sound: "new_order.caf"   },
  waiter_call: { android_channel_id: "waiter_call_channel", ios_sound: "waiter_call.caf" },
};

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED HELPERS  (OneSignal notifications)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Send a OneSignal push notification to a single player.
 * @param {string} playerId  - OneSignal player/subscription ID
 * @param {string} heading   - Notification title
 * @param {string} body      - Notification body
 * @param {object} data      - Extra data payload
 * @param {string} sound     - Key from SOUND_CONFIG: "new_order" | "waiter_call"
 */
async function sendOneSignalNotification(playerId, heading, body, data = {}, sound = "new_order") {
  const cfg = SOUND_CONFIG[sound] ?? SOUND_CONFIG["new_order"];

  const payload = {
    app_id:             ONE_SIGNAL_APP_ID,
    include_player_ids: [playerId],
    headings:           { en: heading },
    contents:           { en: body },

    // ── Custom sound ──────────────────────────────────────────────────────────
    // Android: filename WITHOUT extension — file must be in res/raw/
    android_sound:      sound,
    // iOS: filename WITH extension — file must be in Runner/ bundle
    ios_sound:          cfg.ios_sound,

    // ── Priority & visibility (wake screen like Swiggy / Zomato) ─────────────
    priority:           10,               // HIGH — delivers immediately
    android_visibility: 1,               // VISIBILITY_PUBLIC — shows on lock screen

    // ── Badge ─────────────────────────────────────────────────────────────────
    android_badge_type:  "Increase",
    android_badge_count: 1,

    // ── Appearance ────────────────────────────────────────────────────────────
    small_icon: "ic_stat_onesignal_default",
    large_icon: "ic_launcher",

    data,
  };

  console.log("📦 OneSignal Payload:", JSON.stringify(payload, null, 2));

  return axios.post(
    "https://onesignal.com/api/v1/notifications",
    payload,
    {
      headers: {
        "Content-Type": "application/json",
        Authorization:  `Basic ${ONE_SIGNAL_API_KEY}`,
      },
    }
  );
}

/**
 * Returns OneSignal player IDs from the managers sub-collection.
 */
async function getManagerPlayerIds(db, restaurantId) {
  const snap = await db
    .collection("restaurants")
    .doc(restaurantId)
    .collection("managers")
    .get();

  const ids = [];
  snap.forEach((doc) => {
    const pid = doc.data()?.onesignalPlayerId;
    if (pid && pid.trim() !== "") ids.push(pid.trim());
  });
  return ids;
}

/**
 * Returns all unique player IDs — admin (restaurant doc) + all managers.
 */
async function getAllRecipientPlayerIds(db, restaurantId) {
  const [restaurantDoc, managerIds] = await Promise.all([
    db.collection("restaurants").doc(restaurantId).get(),
    getManagerPlayerIds(db, restaurantId),
  ]);
  const ownerPlayerId = restaurantDoc.data()?.onesignalPlayerId;
  const all = ownerPlayerId ? [ownerPlayerId, ...managerIds] : [...managerIds];
  return [...new Set(all)]; // deduplicate
}

/**
 * Fan-out a notification to multiple players.
 * @param {string[]} playerIds
 * @param {string}   heading
 * @param {string}   body
 * @param {object}   data
 * @param {string}   sound  - "new_order" | "waiter_call"
 */
async function fanOut(playerIds, heading, body, data = {}, sound = "new_order") {
  const results = await Promise.allSettled(
    playerIds.map((pid) => sendOneSignalNotification(pid, heading, body, data, sound))
  );
  results.forEach((r, i) => {
    if (r.status === "fulfilled") {
      console.log(`✅ Sent to playerIds[${i}] | HTTP ${r.value.status}`);
    } else {
      console.error(`❌ Failed for playerIds[${i}]:`, r.reason?.message);
    }
  });
}

function buildTableLabel(order) {
  if (order.orderType === "Parcel") return "Parcel 📦";
  return order.tableName || order.tableId || "Dine In";
}

// ─────────────────────────────────────────────────────────────────────────────
//  NEW ORDER NOTIFICATION  — fires once on order created, sound: "new_order"
//  Path: restaurants/{restaurantId}/orders/{orderId}
// ─────────────────────────────────────────────────────────────────────────────

exports.sendNewOrderNotification = onDocumentCreated(
  "restaurants/{restaurantId}/orders/{orderId}",
  async (event) => {
    try {
      console.log("🔥 sendNewOrderNotification triggered");

      const order        = event.data.data();
      const restaurantId = event.params.restaurantId;
      const orderId      = event.params.orderId;

      const db        = admin.firestore();
      const playerIds = await getAllRecipientPlayerIds(db, restaurantId);

      console.log(`📱 Recipients (${playerIds.length}):`, playerIds);
      if (playerIds.length === 0) {
        console.log("⚠️ No playerIds found — skipping notification");
        return;
      }

      const tableLabel   = buildTableLabel(order);
      const itemCount    = (order.items || []).length;
      const totalAmount  = order.totalAmount  || 0;
      const tokenNumber  = order.tokenNumber  || "";
      const customerName = order.customerName || "";
      const mobile       = order.mobile       || "";

      const heading = `New Order 🍽️ — ${tableLabel}`;
      const body = [
        customerName || "Customer",
        tokenNumber  ? `Token #${tokenNumber}` : null,
        `${itemCount} item${itemCount !== 1 ? "s" : ""}`,
        `₹${totalAmount}`,
        mobile       ? `📞 ${mobile}` : null,
      ].filter(Boolean).join(" • ");

      await fanOut(
        playerIds,
        heading,
        body,
        {
          type:        "new_order",
          orderId,
          restaurantId,
          tableId:     order.tableId   || "",
          tableName:   order.tableName || "",
          orderType:   order.orderType || "",
          tokenNumber: String(tokenNumber),
        },
        "new_order" // 🔊 plays new_order.mp3 / new_order.caf
      );

    } catch (error) {
      console.error("❌ sendNewOrderNotification ERROR");
      error.response
        ? console.error("HTTP", error.response.status, JSON.stringify(error.response.data))
        : console.error("Message:", error.message);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
//  ASSISTANCE REQUEST NOTIFICATIONS  — sound: "waiter_call"
//  Path: restaurants/{restaurantId}/assistance_requests/{requestId}
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
      console.log("🔥 sendAssistanceRequestNotification triggered");

      const request      = event.data.data();
      const restaurantId = event.params.restaurantId;
      const requestId    = event.params.requestId;

      const db        = admin.firestore();
      const playerIds = await getAllRecipientPlayerIds(db, restaurantId);

      console.log(`📱 Recipients (${playerIds.length}):`, playerIds);
      if (playerIds.length === 0) {
        console.log("⚠️ No playerIds found — skipping notification");
        return;
      }

      const typeKey    = request.type || "call_waiter";
      const typeLabel  = REQUEST_TYPE_LABELS[typeKey] || typeKey;
      const tableLabel = request.tableName || request.tableId || "Unknown Table";
      const note       = (request.note || "").trim();

      const heading = `Assistance Needed — ${tableLabel}`;
      const body    = note ? `${typeLabel} • "${note}"` : typeLabel;

      await fanOut(
        playerIds,
        heading,
        body,
        {
          type:        "assistance_request",
          requestId,
          restaurantId,
          requestType: typeKey,
          tableId:     request.tableId   || "",
          tableName:   request.tableName || "",
        },
        "waiter_call" // 🔊 plays waiter_call.mp3 / waiter_call.caf
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
        pending:      "acknowledged",
        acknowledged: "on_the_way",
        on_the_way:   "completed",
      };
      if (validTransitions[before.status] !== after.status) return;

      console.log(`🔥 sendAssistanceStatusNotification: ${before.status} → ${after.status}`);

      const restaurantId = event.params.restaurantId;
      const requestId    = event.params.requestId;

      const db        = admin.firestore();
      const playerIds = await getAllRecipientPlayerIds(db, restaurantId);

      if (playerIds.length === 0) {
        console.log("⚠️ No playerIds found — skipping notification");
        return;
      }

      const typeKey    = after.type || "call_waiter";
      const typeLabel  = REQUEST_TYPE_LABELS[typeKey] || typeKey;
      const tableLabel = after.tableName || after.tableId || "Unknown Table";

      const statusLabels = {
        acknowledged: "Acknowledged ✅",
        on_the_way:   "Waiter On the Way 🚶",
        completed:    "Completed 🎉",
      };
      const statusLabel = statusLabels[after.status] || after.status;

      const heading = `Request ${statusLabel} — ${tableLabel}`;
      const body    = `${typeLabel} has been marked as "${after.status}"`;

      await fanOut(
        playerIds,
        heading,
        body,
        {
          type:        "assistance_status_update",
          requestId,
          restaurantId,
          requestType: typeKey,
          status:      after.status,
          tableId:     after.tableId   || "",
          tableName:   after.tableName || "",
        },
        "waiter_call" // 🔊 plays waiter_call.mp3 / waiter_call.caf
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

const OCR_PROMPT = `
You are an expert at reading Indian restaurant menu images and extracting structured data.

Return ONLY JSON array.
`;

function escapeCsv(value) {
  const str = String(value);
  if (str.includes(",") || str.includes('"') || str.includes("\n")) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

exports.menuImageToCsv = onRequest(
  {
    timeoutSeconds: 60,
    memory:         "512MiB",
    secrets:        ["GEMINI_API_KEY"],
  },
  async (req, res) => {
    cors(req, res, async () => {
      if (req.method !== "POST") {
        return res.status(405).json({ error: "Method not allowed" });
      }

      const { image, mimeType = "image/jpeg" } = req.body;

      if (!image) {
        return res.status(400).json({ error: "No image data provided." });
      }

      try {
        const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({ model: GEMINI_MODEL });

        const result = await model.generateContent([
          { text: OCR_PROMPT },
          { inlineData: { mimeType, data: image } },
        ]);

        const rawText = result.response.text().trim();
        let parsed;

        try {
          const cleaned = rawText
            .replace(/^```json\s*/i, "")
            .replace(/^```\s*/i,     "")
            .replace(/```\s*$/i,     "")
            .trim();

          const start = cleaned.indexOf("[");
          const end   = cleaned.lastIndexOf("]");

          if (start === -1 || end === -1) {
            throw new Error("No JSON array found");
          }

          parsed = JSON.parse(cleaned.substring(start, end + 1));
        } catch (e) {
          console.error("JSON parse failed:", e.message);
          return res.status(500).json({
            error: "Could not read the menu structure.",
          });
        }

        if (!Array.isArray(parsed)) {
          return res.status(500).json({
            error: "Unexpected AI response format.",
          });
        }

        const seen    = new Set();
        const csvRows = [];
        const items   = [];

        for (const item of parsed) {
          const name     = String(item.name     || "").trim();
          const category = String(item.category || "").trim();

          if (!name || !category) continue;

          const rawVariants   = Array.isArray(item.variants) ? item.variants : [];
          const validVariants = [];

          for (const v of rawVariants) {
            const vName  = String(v.name  || "").trim();
            const vPrice = Number(v.price);

            if (!vName || isNaN(vPrice) || vPrice <= 0) continue;

            const key = `${name}||${category}||${vName}`;
            if (seen.has(key)) continue;
            seen.add(key);

            validVariants.push({ name: vName, price: vPrice });
            csvRows.push(
              `${escapeCsv(name)},${escapeCsv(category)},${escapeCsv(vName)},${vPrice.toFixed(2)}`
            );
          }

          if (validVariants.length === 0) continue;

          items.push({ name, category, variants: validVariants });
        }

        const csv = ["name,category,variant_name,price", ...csvRows].join("\n");

        return res.status(200).json({ items, csv });
      } catch (err) {
        console.error("menuImageToCsv error:", err.message);
        return res.status(500).json({ error: "An unexpected error occurred." });
      }
    });
  }
);