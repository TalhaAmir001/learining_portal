# Support Chat Solution: Multiple Admins, Students/Teachers → Admin Only

## Requirement (summary)

- **Multiple admins** are available for support.
- **Students and teachers** may only chat with **admin** user types (not with each other or with non-admin staff).
- **Any admin** can open a support conversation and help (not tied to one specific admin).

---

## Current State vs Requirement

| Aspect | Current behavior | Required behavior |
|--------|------------------|-------------------|
| **Who students/teachers see** | All users from Firestore `user` (except self) via `MembersProvider` | Only admin user types (or a single “Support” entry) |
| **Who admins see** | All users | Can see all support conversations and reply (any admin can “get into” a chat) |
| **Chat model** | 1:1 connection between two `fl_chat_users` (e.g. student ↔ one staff) | Either: (A) one shared “Support” chat per student/teacher, or (B) one chat per student/teacher ↔ one admin, with admins able to see/take over |
| **Backend** | `staff` / `student` only; no notion of “admin” vs “teacher” or “Support” | Support either a virtual “Support” user or admin-only visibility for support chats |

---

## Recommended Approach: Single “Support” User (Shared Inbox)

So that **any admin can get into the chat** without reassigning connections:

1. **One virtual “Support” chat user** in `fl_chat_users` (e.g. a dedicated `staff_id` used only for support, or a convention like `staff_id = 0` if your schema allows).
2. **Students and teachers** see only **“Support”** in “Select User” (or one entry that creates a connection to this Support user).
3. **One connection per student/teacher** to Support: e.g. `(chat_user_student, chat_user_support)` or `(chat_user_teacher, chat_user_support)`.
4. **Admins** use a **Support Inbox** that lists all connections where the “other” side is this Support user; any admin can open a conversation and send messages **on behalf of Support** (backend stores message on that connection; optionally store `admin_id` for “who replied”).

Effects:

- Students/teachers only talk to “Support”; no need to pick a specific admin.
- Any admin can open any support thread and reply; no per-admin connection needed.
- Existing 1:1 connection and message tables can be reused; only the “other” participant is always the same Support user.

---

## Alternative: Students/Teachers See List of Admins

If you prefer **no** virtual Support user:

- **Students/teachers** see only **admin** users in “Select User” (filter by `UserType.admin` in Firestore).
- Each conversation is 1:1 with **one** admin (e.g. first one they pick).
- So that “any admin can get into the chat” you would need either:
  - **Reassignment**: transfer the connection from Admin A to Admin B (schema/API support to change which staff is in the connection), or
  - **Shared view**: all admins can see and reply in any “support” connection (backend would need to allow multiple staff to send in the same connection and optionally show “who replied”).

This is more complex (reassignment or multi-sender in one connection) and still requires backend changes. The **single Support user** approach is simpler and matches “any admin can get into the chat” with minimal schema change.

---

## Implementation Outline (No Code Changes Here – Plan Only)

### 1. Flutter app

**1.1 Restrict who students/teachers can chat with (`MembersProvider`)**

- **File:** `lib/providers/messages/members_provider.dart`
- **Change:** When current user is **student** or **teacher**, filter the list so only **admin** users are shown (e.g. `user.userType == UserType.admin`).
- **Optional (Support approach):** Instead of a list of admins, show a single “Support” tile (e.g. synthetic `UserModel` with a fixed `uid` agreed with backend). Tapping it opens chat with that “Support” user (same `initializeChat(SupportUid)` flow you use today).

**1.2 Optional: Support Inbox for admins**

- **Concept:** When current user is **admin**, the Inbox could show:
  - Either: all connections where the other party is the virtual Support user (i.e. “support” conversations where this app user is acting as Support), **or**
  - A separate “Support” tab/screen that lists those same conversations.
- **Backend:** Must expose connections for “Support” (e.g. `get_connections` for the Support `user_id` / `user_type`) so the app can show them. Admins then open a conversation and send messages; backend accepts from any admin and associates the message with the Support connection (and optionally stores which admin sent it).

**1.3 Who can contact whom (rules)**

- **Students / teachers:** Can only open chats with admins (or with the single “Support” user). Enforced by:
  - Only showing admins (or “Support”) in `MembersProvider` for these roles.
- **Admins:** Can open any conversation they are allowed to see (e.g. their own 1:1 chats + Support Inbox). No change needed for “only chat with admin” for students/teachers; the restriction is on the student/teacher side.

**1.4 Inbox / Chat screens**

- **Inbox:** Already shows connections returned by `get_connections`. For Support flow, backend must return support connections when the logged-in user is an admin acting as Support (or when querying as the Support user).
- **Chat:** No change to 1:1 chat UI; only the way the “other” user is chosen (admins only or Support) and how admins see support threads.

### 2. Backend (APIs + DB)

**2.1 Virtual Support user**

- **DB:** Ensure one row in `fl_chat_users` for Support (e.g. `staff_id = <support_staff_id>`, `user_type = 'staff'`). All support connections use this `chat_user_id` on the “support” side.
- **API:**  
  - **create_connection:** When a student/teacher creates a conversation “with Support”, use their `chat_user_id` and the Support `chat_user_id`.  
  - **get_connections:** For the Support user, return all connections involving that `chat_user_id` (so admins can list all support threads). Optionally, an endpoint like `get_support_connections` that returns the same list when the requester is an admin.

**2.2 Sending messages as Support**

- When an **admin** sends a message in a support thread, backend should:
  - Treat the conversation as the existing (student/teacher ↔ Support) connection.
  - Store the message on that connection (same as today).
  - Optionally store which admin sent it (e.g. `sender_admin_id` or in `fl_chat_messages` metadata) for “who replied”.
- **WebSocket / HTTP:** Accept messages from an admin for a connection where the “other” participant is Support; validate that the sender is an admin and then save as above.

**2.3 get_connections / get_connection**

- **Students/teachers:** Unchanged: they get their own connections (including the one with Support).
- **Admins:** Either:
  - Use existing `get_connections` with Support’s `user_id` when the client is “acting as Support”, or
  - New endpoint that returns all support connections for admin clients.

**2.4 create_chat_user**

- Support user must exist in `fl_chat_users` (created once manually or via migration). No change to the API contract; only ensure Support’s `staff_id` (or chosen id) is registered.

### 3. Database (optional schema notes)

- **fl_chat_users:** One row for Support (e.g. `staff_id = X`, `user_type = 'staff'`). No schema change required if you use an existing staff id.
- **fl_chat_connections:** No change; still (chat_user_one, chat_user_two).
- **fl_chat_messages:** No change; optional extra column for `sender_admin_id` or similar if you want to show “Replied by Admin X”.

### 4. WebSocket server (`websocket_server.php`)

- **send_message:** When the sender is an admin and the connection is a “support” connection (one of the two `chat_user_id`s is Support), allow the message to be stored on that connection (receiver = student/teacher’s `chat_user_id`).
- **create_chat_user:** No change; Support user already exists.
- **connect:** Admins connect with their own `user_id` / `user_type = 'staff'`. When they open a support thread, they use the same `chat_connection_id` (student/teacher ↔ Support); server must accept message from any staff for that connection and persist it under that connection.

---

## Summary Checklist

- [ ] **Backend:** Create or designate one Support user in `fl_chat_users`.
- [ ] **Backend:** Ensure students/teachers can create a connection to Support only (or to any admin if you use the “list of admins” approach).
- [ ] **Backend:** Ensure admins can list all support connections (e.g. get_connections for Support, or dedicated endpoint).
- [ ] **Backend:** Allow admins to send messages on support connections (WebSocket/API).
- [ ] **Flutter – MembersProvider:** For students/teachers, show only admins or only “Support”.
- [ ] **Flutter (optional):** Admin “Support Inbox” that loads and displays support connections.
- [ ] **Firestore:** Ensure admin users have `userType == 'admin'` so the app can filter them (or use a single Support document for the synthetic Support user).

---

## Implementation status (Single “Support” User)

The following has been implemented:

- **Database:** `add_support_chat_user.sql` — inserts Support user (staff_id = 0, user_type = 'staff') into `fl_chat_users`. Run once after your schema.
- **WebSocket server (`websocket_server.php`):**
  - Support constant `SUPPORT_STAFF_ID = 0` and `getSupportChatUserId()`.
  - When a student/teacher sends to Support, the message is broadcast to all connected staff (admins).
  - When an admin sends in a support thread, the message is stored as “from Support” and delivered to the student/teacher.
- **Mobile APIs:** `get_connections.php`, `get_connection.php`, `create_connection.php` in `mobile_apis/` — support Support user (user_id = 0, user_type = 'staff') for listing and creating connections.
- **Flutter:**
  - `supportUserId = '0'` in `lib/utils/constants.dart`.
  - **MembersProvider:** Students and teachers see only “Support”; admins see the Support Inbox (list of support conversation partners).
  - **InboxProvider:** Admins load connections for Support (`supportUserId`, 'staff') so the inbox is the Support Inbox.
  - **ChatProvider:** Correct `otherUserType` and connection lookup when chatting with Support or when admin opens a support thread (uses Support as one party).

**Deployment:** Run `add_support_chat_user.sql` on your database once. Deploy `websocket_server.php` and the `mobile_apis/` PHP files to your backend. Ensure the Flutter app uses the same base URL for these APIs.
