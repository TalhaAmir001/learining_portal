const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Cloud Function to send FCM notification when a new message is created
exports.sendMessageNotification = functions.firestore
    .document('chats/{chatId}/messages/{messageId}')
    .onCreate(async (snap, context) => {
        const message = snap.data();
        const chatId = context.params.chatId;
        const messageId = context.params.messageId;

        // Get chat document to find the recipient
        const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
        if (!chatDoc.exists) {
            console.log('Chat document not found:', chatId);
            return null;
        }

        const chatData = chatDoc.data();
        const senderId = message.senderId;

        // Determine recipient ID
        let recipientId;
        if (chatData.user1Id === senderId) {
            recipientId = chatData.user2Id;
        } else if (chatData.user2Id === senderId) {
            recipientId = chatData.user1Id;
        } else {
            console.log('Sender ID does not match chat participants');
            return null;
        }

        // Get recipient's user document to fetch FCM token and name
        const recipientDoc = await admin.firestore().collection('user').doc(recipientId).get();
        if (!recipientDoc.exists) {
            console.log('Recipient document not found:', recipientId);
            return null;
        }

        const recipientData = recipientDoc.data();
        const fcmToken = recipientData.fcmToken;

        if (!fcmToken) {
            console.log('No FCM token found for recipient:', recipientId);
            return null;
        }

        // Get sender's name
        const senderDoc = await admin.firestore().collection('user').doc(senderId).get();
        let senderName = 'Someone';
        if (senderDoc.exists) {
            const senderData = senderDoc.data();
            senderName = senderData.firstName && senderData.lastName
                ? `${senderData.firstName} ${senderData.lastName}`
                : senderData.displayName || senderData.email?.split('@')[0] || 'Someone';
        }

        // Prepare notification payload
        const notification = {
            title: senderName,
            body: message.text || 'New message',
            sound: 'default',
        };

        const data = {
            chatId: chatId,
            messageId: messageId,
            senderId: senderId,
            type: 'message',
        };

        // Send FCM notification
        const messagePayload = {
            notification: notification,
            data: data,
            token: fcmToken,
            android: {
                priority: 'high',
                notification: {
                    channelId: 'messages_channel',
                    sound: 'default',
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                    },
                },
            },
        };

        try {
            const response = await admin.messaging().send(messagePayload);
            console.log('Successfully sent message notification:', response);
            return response;
        } catch (error) {
            console.error('Error sending message notification:', error);
            return null;
        }
    });
