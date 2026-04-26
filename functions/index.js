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

const ONE_SIGNAL_APP_ID =
  "1dbbdcbd-590f-475c-88d0-7c6d953d63ca";

const ONE_SIGNAL_API_KEY =
  "os_v2_app_dw55zpkzb5dvzcgqprwzkpldzivurcpwolgusj5jpri7rvhimxgq47fawbgyfacazhxm2rs67zqtxsna3h6oll7qbkjrlsx3ecfbsyi";

// ─────────────────────────────────────────────────────────────────────────────
// ASSIGN RESTAURANT CLAIMS
// ─────────────────────────────────────────────────────────────────────────────

exports.assignRestaurantClaim = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User not authenticated"
      );
    }

    const uid = request.auth.uid;
    const restaurantId = request.data.restaurantId;

    if (!restaurantId || typeof restaurantId !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "restaurantId is required"
      );
    }

    // Set Firebase custom claims
    await admin.auth().setCustomUserClaims(uid, {
      restaurantId,
      role: "owner",
    });

    // Save optional user info
    await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .set(
        {
          uid,
          restaurantId,
          role: "owner",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    console.log(`✅ Claims assigned for UID: ${uid}`);

    return {
      success: true,
      restaurantId,
    };
  } catch (error) {
    console.error("❌ assignRestaurantClaim ERROR:", error);

    throw new HttpsError(
      "internal",
      error.message || "Something went wrong"
    );
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS (OneSignal notifications)
// ─────────────────────────────────────────────────────────────────────────────

async function sendOneSignalNotification(
  playerId,
  heading,
  body,
  data = {}
) {
  const payload = {
    app_id: ONE_SIGNAL_APP_ID,
    include_player_ids: [playerId],
    headings: { en: heading },
    contents: { en: body },
    android_sound: "new_order",
    ios_sound: "new_order.mp3",
    small_icon: "ic_stat_onesignal_default",
    large_icon: "ic_launcher",
    data,
  };

  return axios.post(
    "https://onesignal.com/api/v1/notifications",
    payload,
    {
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${ONE_SIGNAL_API_KEY}`,
      },
    }
  );
}

async function getManagerPlayerIds(db, restaurantId) {
  const snap = await db
    .collection("restaurants")
    .doc(restaurantId)
    .collection("managers")
    .get();

  const ids = [];

  snap.forEach((doc) => {
    const pid = doc.data()?.onesignalPlayerId;

    if (pid && pid.trim() !== "") {
      ids.push(pid.trim());
    }
  });

  return ids;
}

async function getAllRecipientPlayerIds(db, restaurantId) {
  const [restaurantDoc, managerIds] = await Promise.all([
    db.collection("restaurants").doc(restaurantId).get(),
    getManagerPlayerIds(db, restaurantId),
  ]);

  const ownerPlayerId =
    restaurantDoc.data()?.onesignalPlayerId;

  const all = ownerPlayerId
    ? [ownerPlayerId, ...managerIds]
    : [...managerIds];

  return [...new Set(all)];
}

async function fanOut(
  playerIds,
  heading,
  body,
  data = {}
) {
  const results = await Promise.allSettled(
    playerIds.map((pid) =>
      sendOneSignalNotification(
        pid,
        heading,
        body,
        data
      )
    )
  );

  results.forEach((r, i) => {
    if (r.status === "fulfilled") {
      console.log(`✅ Sent to playerIds[${i}]`);
    } else {
      console.error(
        `❌ Failed for playerIds[${i}]:`,
        r.reason?.message
      );
    }
  });
}

function buildTableLabel(order) {
  if (order.orderType === "Parcel") {
    return "Parcel 📦";
  }

  return (
    order.tableName ||
    order.tableId ||
    "Dine In"
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MENU IMAGE → CSV
// ─────────────────────────────────────────────────────────────────────────────

const GEMINI_MODEL = "gemini-1.5-flash";

const OCR_PROMPT = `
You are an expert at reading Indian restaurant menu images and extracting structured data.

Return ONLY JSON array.
`;

function escapeCsv(value) {
  const str = String(value);

  if (
    str.includes(",") ||
    str.includes('"') ||
    str.includes("\n")
  ) {
    return `"${str.replace(/"/g, '""')}"`;
  }

  return str;
}

exports.menuImageToCsv = onRequest(
  {
    timeoutSeconds: 60,
    memory: "512MiB",
    secrets: ["GEMINI_API_KEY"],
  },
  async (req, res) => {
    cors(req, res, async () => {
      if (req.method !== "POST") {
        return res
          .status(405)
          .json({ error: "Method not allowed" });
      }

      const {
        image,
        mimeType = "image/jpeg",
      } = req.body;

      if (!image) {
        return res.status(400).json({
          error: "No image data provided.",
        });
      }

      try {
        const genAI = new GoogleGenerativeAI(
          process.env.GEMINI_API_KEY
        );

        const model =
          genAI.getGenerativeModel({
            model: GEMINI_MODEL,
          });

        const result =
          await model.generateContent([
            { text: OCR_PROMPT },
            {
              inlineData: {
                mimeType,
                data: image,
              },
            },
          ]);

        const rawText =
          result.response.text().trim();

        let parsed;

        try {
          const cleaned = rawText
            .replace(/^```json\s*/i, "")
            .replace(/^```\s*/i, "")
            .replace(/```\s*$/i, "")
            .trim();

          const start = cleaned.indexOf("[");
          const end = cleaned.lastIndexOf("]");

          if (start === -1 || end === -1) {
            throw new Error(
              "No JSON array found"
            );
          }

          parsed = JSON.parse(
            cleaned.substring(start, end + 1)
          );
        } catch (e) {
          console.error(
            "JSON parse failed:",
            e.message
          );

          return res.status(500).json({
            error:
              "Could not read the menu structure.",
          });
        }

        if (!Array.isArray(parsed)) {
          return res.status(500).json({
            error:
              "Unexpected AI response format.",
          });
        }

        const seen = new Set();
        const csvRows = [];
        const items = [];

        for (const item of parsed) {
          const name = String(
            item.name || ""
          ).trim();

          const category = String(
            item.category || ""
          ).trim();

          if (!name || !category) {
            continue;
          }

          const rawVariants = Array.isArray(
            item.variants
          )
            ? item.variants
            : [];

          const validVariants = [];

          for (const v of rawVariants) {
            const vName = String(
              v.name || ""
            ).trim();

            const vPrice = Number(v.price);

            if (
              !vName ||
              isNaN(vPrice) ||
              vPrice <= 0
            ) {
              continue;
            }

            const key =
              `${name}||${category}||${vName}`;

            if (seen.has(key)) {
              continue;
            }

            seen.add(key);

            validVariants.push({
              name: vName,
              price: vPrice,
            });

            csvRows.push(
              `${escapeCsv(name)},${escapeCsv(
                category
              )},${escapeCsv(
                vName
              )},${vPrice.toFixed(2)}`
            );
          }

          if (validVariants.length === 0) {
            continue;
          }

          items.push({
            name,
            category,
            variants: validVariants,
          });
        }

        const csv = [
          "name,category,variant_name,price",
          ...csvRows,
        ].join("\n");

        return res.status(200).json({
          items,
          csv,
        });
      } catch (err) {
        console.error(
          "menuImageToCsv error:",
          err.message
        );

        return res.status(500).json({
          error:
            "An unexpected error occurred.",
        });
      }
    });
  }
);