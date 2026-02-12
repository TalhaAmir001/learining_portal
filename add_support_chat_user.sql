-- =====================================================
-- Support Chat User (Shared Inbox)
-- =====================================================
-- Inserts the virtual "Support" user into fl_chat_users so that
-- students and teachers have a single contact for support.
-- Any admin can reply on behalf of Support.
--
-- Support uses staff_id = 0, user_type = 'staff'.
-- Run this once after database_schema.sql (and add_fcm_token_column.sql if used).
-- =====================================================

INSERT INTO `fl_chat_users` (`staff_id`, `student_id`, `user_type`, `created_at`, `updated_at`)
VALUES (0, NULL, 'staff', NOW(), NOW())
ON DUPLICATE KEY UPDATE `updated_at` = NOW();

-- Note: If your schema uses UNIQUE KEY (staff_id, user_type), the above
-- ensures one row for (staff_id=0, user_type='staff').
-- If you get a duplicate-key error, the Support user may already exist.
