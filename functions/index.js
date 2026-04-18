const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

const ONE_SIGNAL_APP_ID  = "1dbbdcbd-590f-475c-88d0-7c6d953d63ca";
const ONE_SIGNAL_API_KEY = "os_v2_app_dw55zpkzb5dvzcgqprwzkpldzjm6ev35mkvukdvbgjdnyckppn47t5kmesslhxckjjvnob7kub7y5gs6jweihy73ly6xjaurudzcwua";

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/**
 * POST a single push notification via OneSignal REST API.
 */
async function sendOneSignalNotification(playerId, heading, body, data = {}) {
  const payload = {
    app_id:             ONE_SIGNAL_APP_ID,
    include_player_ids: [playerId],
    headings:           { en: heading },
    contents:           { en: body },
    android_sound:      "new_order",
    ios_sound:          "new_order.mp3",
    small_icon:         "ic_stat_onesignal_default",
    large_icon:         "ic_launcher",
    data,
  };
  console.log("📦 Payload:", JSON.stringify(payload, null, 2));
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
 * Collect onesignalPlayerId from every manager doc under
 * restaurants/{restaurantId}/managers/{uid}.
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
 * Returns de-duplicated player IDs for:
 *   • restaurant owner  (restaurants/{id}.onesignalPlayerId)
 *   • every manager     (restaurants/{id}/managers/{uid}.onesignalPlayerId)
 */
async function getAllRecipientPlayerIds(db, restaurantId) {
  const [restaurantDoc, managerIds] = await Promise.all([
    db.collection("restaurants").doc(restaurantId).get(),
    getManagerPlayerIds(db, restaurantId),
  ]);
  const ownerPlayerId = restaurantDoc.data()?.onesignalPlayerId;
  const all = ownerPlayerId ? [ownerPlayerId, ...managerIds] : [...managerIds];
  return [...new Set(all)];
}

/**
 * Fan-out a notification to all playerIds in parallel.
 * Promise.allSettled ensures one failure doesn't block others.
 */
async function fanOut(playerIds, heading, body, data = {}) {
  const results = await Promise.allSettled(
    playerIds.map((pid) => sendOneSignalNotification(pid, heading, body, data))
  );
  results.forEach((r, i) => {
    if (r.status === "fulfilled") {
      console.log(`✅ Sent to playerIds[${i}] | HTTP ${r.value.status}`);
    } else {
      console.error(`❌ Failed for playerIds[${i}]:`, r.reason?.message);
    }
  });
}

/**
 * Build a human-readable table / order-type label from an order document.
 *
 * Fields from cart_page.dart → placeOrder():
 *   orderType : "Dine In" | "Parcel"
 *   tableId   : string | null
 *   tableName : string | null   ← this is the correct field (not tableNumber)
 */
function buildTableLabel(order) {
  if (order.orderType === "Parcel") return "Parcel 📦";
  return order.tableName || order.tableId || "Dine In";
}

// ─────────────────────────────────────────────────────────────────────────────
//  ORDER NOTIFICATIONS
//
//  ✅ FIXED — Firestore path is a subcollection:
//     restaurants/{restaurantId}/orders/{orderId}
//     (was incorrectly "orders/{orderId}" top-level — that collection
//      does not exist in the actual database)
//
//  ✅ FIXED — Field mapping corrected to match cart_page.dart placeOrder():
//     order.tableNumber  ❌  →  order.tableName / order.tableId  ✅
//     i.status filter    ❌  →  items have no status field; count directly ✅
//     restaurantId       now read from event.params (more reliable)  ✅
// ─────────────────────────────────────────────────────────────────────────────

// ── New order placed by customer ──────────────────────────────────────────────
exports.sendNewOrderNotification = onDocumentCreated(
  // ✅ FIXED path — was "orders/{orderId}"
  "restaurants/{restaurantId}/orders/{orderId}",
  async (event) => {
    try {
      console.log("🔥 sendNewOrderNotification triggered");

      const order        = event.data.data();
      const restaurantId = event.params.restaurantId; // from path — reliable
      const orderId      = event.params.orderId;

      const db        = admin.firestore();
      const playerIds = await getAllRecipientPlayerIds(db, restaurantId);

      console.log(`📱 Recipients (${playerIds.length}):`, playerIds);
      if (playerIds.length === 0) {
        console.log("❌ No playerIds found — skipping");
        return;
      }

      // ✅ FIXED: tableName/tableId (not tableNumber — field doesn't exist)
      const tableLabel   = buildTableLabel(order);
      // ✅ FIXED: items have no status field — just count all of them
      const itemCount    = (order.items || []).length;
      const totalAmount  = order.totalAmount  || 0;
      const tokenNumber  = order.tokenNumber  || "";
      const customerName = order.customerName || "";
      const mobile       = order.mobile       || "";

      const heading = `New Order 🍽️ — ${tableLabel}`;
      const body = [
        customerName || "Customer",
        tokenNumber ? `Token #${tokenNumber}` : null,
        `${itemCount} item${itemCount !== 1 ? "s" : ""}`,
        `₹${totalAmount}`,
        mobile ? `📞 ${mobile}` : null,
      ].filter(Boolean).join(" • ");

      await fanOut(playerIds, heading, body, {
        type:        "new_order",
        orderId,
        restaurantId,
        // ✅ FIXED: correct field names for deep-link navigation
        tableId:     order.tableId   || "",
        tableName:   order.tableName || "",
        orderType:   order.orderType || "",
        tokenNumber: String(tokenNumber),
      });

    } catch (error) {
      console.error("❌ sendNewOrderNotification ERROR");
      error.response
        ? console.error("HTTP", error.response.status, JSON.stringify(error.response.data))
        : console.error("Message:", error.message);
    }
  }
);

// ── Order items updated by customer ──────────────────────────────────────────
exports.sendOrderUpdatedNotification = onDocumentUpdated(
  // ✅ FIXED path
  "restaurants/{restaurantId}/orders/{orderId}",
  async (event) => {
    try {
      const before = event.data.before.data();
      const after  = event.data.after.data();

      // Only fire when the items array actually changed (customer adding items).
      // Ignore pure status / updatedAt / sessionIds changes from the restaurant.
      const itemsBefore = JSON.stringify(before.items ?? []);
      const itemsAfter  = JSON.stringify(after.items  ?? []);
      if (itemsBefore === itemsAfter) return;

      // Don't re-notify on completed or cancelled orders.
      if (["completed", "cancelled"].includes((after.status ?? "").toLowerCase())) return;

      const restaurantId = event.params.restaurantId;
      const orderId      = event.params.orderId;

      const db        = admin.firestore();
      const playerIds = await getAllRecipientPlayerIds(db, restaurantId);

      if (playerIds.length === 0) {
        console.log("❌ No playerIds found — skipping");
        return;
      }

      // ✅ FIXED: correct field names
      const tableLabel   = buildTableLabel(after);
      // ✅ FIXED: items have no status field — count all items
      const itemCount    = (after.items || []).length;
      const totalAmount  = after.totalAmount  || 0;
      const tokenNumber  = after.tokenNumber  || "";
      const customerName = after.customerName || "";

      const heading = `Order Updated 🔄 — ${tableLabel}`;
      const body = [
        customerName || "Customer",
        tokenNumber ? `Token #${tokenNumber}` : null,
        `${itemCount} item${itemCount !== 1 ? "s" : ""}`,
        `₹${totalAmount}`,
      ].filter(Boolean).join(" • ");

      await fanOut(playerIds, heading, body, {
        type:        "order_updated",
        orderId,
        restaurantId,
        tableId:     after.tableId   || "",
        tableName:   after.tableName || "",
        orderType:   after.orderType || "",
        tokenNumber: String(tokenNumber),
      });

    } catch (error) {
      console.error("❌ sendOrderUpdatedNotification ERROR");
      error.response
        ? console.error("HTTP", error.response.status, JSON.stringify(error.response.data))
        : console.error("Message:", error.message);
    }
  }
);

// ── Order status changed by restaurant (pending → preparing → ready → completed) ─
exports.sendOrderStatusNotification = onDocumentUpdated(
  "restaurants/{restaurantId}/orders/{orderId}",
  async (event) => {
    try {
      const before = event.data.before.data();
      const after  = event.data.after.data();

      // Only fire when status field actually changed
      if (before.status === after.status) return;

      // Don't re-fire if items also changed in the same write
      // (that is handled by sendOrderUpdatedNotification)
      const itemsBefore = JSON.stringify(before.items ?? []);
      const itemsAfter  = JSON.stringify(after.items  ?? []);
      if (itemsBefore !== itemsAfter) return;

      console.log(`🔥 sendOrderStatusNotification: ${before.status} → ${after.status}`);

      const restaurantId = event.params.restaurantId;
      const orderId      = event.params.orderId;

      const db        = admin.firestore();
      const playerIds = await getAllRecipientPlayerIds(db, restaurantId);

      if (playerIds.length === 0) {
        console.log("❌ No playerIds found — skipping");
        return;
      }

      const tableLabel   = buildTableLabel(after);
      const tokenNumber  = after.tokenNumber  || "";
      const customerName = after.customerName || "";
      const totalAmount  = after.totalAmount  || 0;

      const statusLabels = {
        pending:   "Order Received 🕐",
        preparing: "Preparing 👨‍🍳",
        ready:     "Ready to Serve ✅",
        completed: "Completed 🎉",
        cancelled: "Cancelled ❌",
      };
      const statusLabel = statusLabels[after.status] || after.status;

      const heading = `${statusLabel} — ${tableLabel}`;
      const body = [
        customerName || "Customer",
        tokenNumber ? `Token #${tokenNumber}` : null,
        `₹${totalAmount}`,
      ].filter(Boolean).join(" • ");

      await fanOut(playerIds, heading, body, {
        type:        "order_status_update",
        orderId,
        restaurantId,
        status:      after.status,
        tableId:     after.tableId   || "",
        tableName:   after.tableName || "",
        orderType:   after.orderType || "",
        tokenNumber: String(tokenNumber),
      });

    } catch (error) {
      console.error("❌ sendOrderStatusNotification ERROR");
      error.response
        ? console.error("HTTP", error.response.status, JSON.stringify(error.response.data))
        : console.error("Message:", error.message);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
//  ASSISTANCE REQUEST NOTIFICATIONS  (path + fields were already correct)
//  Path: restaurants/{restaurantId}/assistance_requests/{requestId}
// ─────────────────────────────────────────────────────────────────────────────

const REQUEST_TYPE_LABELS = {
  call_waiter: "Call Waiter 🔔",
  water:       "Water 💧",
  order:       "Order 🧾",
  bill:        "Bill 💳",
};

// ── New assistance request submitted by customer ──────────────────────────────
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
        console.log("❌ No playerIds found — skipping");
        return;
      }

      const typeKey    = request.type || "call_waiter";
      const typeLabel  = REQUEST_TYPE_LABELS[typeKey] || typeKey;
      const tableLabel = request.tableName || request.tableId || "Unknown Table";
      const note       = (request.note || "").trim();

      const heading = `Assistance Needed — ${tableLabel}`;
      const body    = note ? `${typeLabel} • "${note}"` : typeLabel;

      await fanOut(playerIds, heading, body, {
        type:        "assistance_request",
        requestId,
        restaurantId,
        requestType: typeKey,
        tableId:     request.tableId   || "",
        tableName:   request.tableName || "",
      });

    } catch (error) {
      console.error("❌ sendAssistanceRequestNotification ERROR:", error.message);
    }
  }
);

// ── Assistance request status advanced by manager / owner ─────────────────────
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
        console.log("❌ No playerIds found — skipping");
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

      await fanOut(playerIds, heading, body, {
        type:        "assistance_status_update",
        requestId,
        restaurantId,
        requestType: typeKey,
        status:      after.status,
        tableId:     after.tableId   || "",
        tableName:   after.tableName || "",
      });

    } catch (error) {
      console.error("❌ sendAssistanceStatusNotification ERROR:", error.message);
    }
  }
);