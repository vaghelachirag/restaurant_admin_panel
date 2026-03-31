const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

const ONE_SIGNAL_APP_ID = "1dbbdcbd-590f-475c-88d0-7c6d953d63ca";
const ONE_SIGNAL_API_KEY = "os_v2_app_dw55zpkzb5dvzcgqprwzkpldzjlt3zxqo2qedf5gkdktmnzrssyamevymraztk3cb776q6va5fkyuivr7ruyvquzmnzcorefna6erti";

exports.sendNewOrderNotification = onDocumentCreated(
  "orders/{orderId}",
  async (event) => {
    try {
      const order = event.data.data();
      const restaurantId = order.restaurantId;

      const db = admin.firestore();

      const restaurantDoc = await db
        .collection("restaurants")
        .doc(restaurantId)
        .get();

        console.log("🔥 Function triggered");

      const playerId = restaurantDoc.data()?.onesignalPlayerId;

      if (!playerId) {
        console.log("No playerId found");
        return;
      }

      const response = await axios.post(
        "https://onesignal.com/api/v1/notifications",
        {
          app_id: ONE_SIGNAL_APP_ID,
          include_player_ids: [playerId],
          headings: { en: "New Order Received 🍽️" },
          contents: {
            en: `Order from ${order.customerName || "Customer"}`,
          },
        },
        {
          headers: {
            "Content-Type": "application/json",
            Authorization: `Basic ${ONE_SIGNAL_API_KEY}`,
          },
        }
      );

      console.log("Notification sent:", response.data);
    } catch (error) {
      console.error("Error sending notification:", error);
    }
  }
);