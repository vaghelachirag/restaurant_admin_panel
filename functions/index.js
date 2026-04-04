const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

const ONE_SIGNAL_APP_ID = "1dbbdcbd-590f-475c-88d0-7c6d953d63ca";
const ONE_SIGNAL_API_KEY = "os_v2_app_dw55zpkzb5dvzcgqprwzkpldzjvihzcuyswecvf65qjbkiu43glrkbarg6cxvafovkjrhohza5qjtmmz7yjcmnehzb75qyztpx23api";

exports.sendNewOrderNotification = onDocumentCreated(
  "orders/{orderId}",
  async (event) => {
    try {
      console.log("🔥 Function triggered");

      const order = event.data.data();
      const restaurantId = order.restaurantId;
      const orderId = event.params.orderId;

      const db = admin.firestore();

      const restaurantDoc = await db
        .collection("restaurants")
        .doc(restaurantId)
        .get();

      const playerId = restaurantDoc.data()?.onesignalPlayerId;

      console.log("📱 Player ID:", playerId);

      if (!playerId) {
        console.log("❌ No playerId found");
        return;
      }


      const itemCount = (order.items || []).length;
      const totalAmount = order.totalAmount || 0;
      const tableLabel = order.tableNumber
        ? `Table ${order.tableNumber}`
        : "Takeaway";

      const heading = `New Order 🍽️ — ${tableLabel}`;
      const body = `${order.customerName || "Customer"} • ${itemCount} item${itemCount !== 1 ? "s" : ""} • ₹${totalAmount}`;

      const payload = {
        app_id: ONE_SIGNAL_APP_ID,
        include_player_ids: [playerId],
        headings: { en: heading },
        contents: { en: body },
        android_sound: "new_order",
        ios_sound: "new_order.mp3",
        small_icon: "ic_stat_onesignal_default",
        large_icon: "ic_launcher",
        data: {
          type: "new_order",
          orderId: orderId,
          restaurantId: restaurantId,
          tableNumber: order.tableNumber || "",
        },
      };

      console.log("📦 Payload:", JSON.stringify(payload, null, 2));

      const response = await axios.post(
        "https://onesignal.com/api/v1/notifications",
        payload,
        {
          headers: {
            "Content-Type": "application/json",
            Authorization: `Basic ${ONE_SIGNAL_API_KEY}`,
          },
        }
      );

      console.log("✅ OneSignal SUCCESS");
      console.log("Status:", response.status);
      console.log("Response:", JSON.stringify(response.data, null, 2));

    } catch (error) {
      console.error("❌ OneSignal ERROR");
      if (error.response) {
        console.error("Status:", error.response.status);
        console.error("Response:", JSON.stringify(error.response.data, null, 2));
      } else {
        console.error("Message:", error.message);
      }
    }
  }
);