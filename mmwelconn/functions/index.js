const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendChatNotification = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const messageData = snapshot.data();
    if (!messageData) return;

    const { chatId } = context.params;
    const senderId = messageData.senderId;
    const senderName = messageData.senderName || "Someone";
    const textMessage = messageData.text || (messageData.imageUrl ? "📷 Sent a photo" : "New message");

    try {
      // 1. Get the parent chat document to find the participants
      const chatDoc = await admin.firestore().collection("chats").doc(chatId).get();
      if (!chatDoc.exists) return;

      const chatData = chatDoc.data();
      if (!chatData || !chatData.participantIds) return;

      // 2. Identify the recipient's UID (the other participant)
      const recipientId = chatData.participantIds.find(id => id !== senderId);
      if (!recipientId) return;

      // 3. Retrieve the recipient's user profile (containing their FCM token and settings)
      const userDoc = await admin.firestore().collection("users").doc(recipientId).get();
      if (!userDoc.exists) return;

      const userData = userDoc.data();
      if (!userData) return;

      // Send the notification if the user has an FCM token, regardless of notificationsEnabled setting
      const fcmToken = userData.fcmToken;

      if (fcmToken) {
        // 4. Build the payload and send the push notification
        const payload = {
          token: fcmToken,
          notification: {
            title: senderName,
            body: textMessage,
          },
          data: {
            chatId: chatId,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        await admin.messaging().send(payload);
        console.log(`Push notification sent successfully to user ${recipientId}`);
      }
    } catch (error) {
      console.error("Error sending push notification:", error);
    }
  });
