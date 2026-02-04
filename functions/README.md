# Firebase Cloud Functions Setup

This directory contains Cloud Functions that send push notifications when new messages are created.

## Setup Instructions

1. **Install Firebase CLI** (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**:
   ```bash
   firebase login
   ```

3. **Initialize Firebase Functions** (if not already done):
   ```bash
   cd functions
   npm install
   ```

4. **Deploy the Cloud Function**:
   ```bash
   firebase deploy --only functions
   ```

## How It Works

The Cloud Function `sendMessageNotification` automatically triggers when a new message is created in Firestore at the path:
```
chats/{chatId}/messages/{messageId}
```

When triggered, it:
1. Determines the recipient of the message
2. Fetches the recipient's FCM token from their user document
3. Fetches the sender's name
4. Sends an FCM push notification to the recipient's device

## Requirements

- Firebase project must have Cloud Functions enabled
- Node.js 18 or higher
- Firebase CLI installed
- Proper Firebase project permissions

## Testing

After deployment, test by sending a message from one user to another. The recipient should receive a push notification even when the app is closed.
