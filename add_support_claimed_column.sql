-- Add support_claimed_by_staff_id to fl_chat_connections
-- When an admin opens a support thread (student <-> Support), we set this to that admin's staff_id
-- so other admins don't see that student in their Support Inbox (only unclaimed or claimed by me).
-- Required for: get_connections (Support inbox filter), claim_support_connection API.
-- Run this once; if column already exists you may see "Duplicate column" (safe to ignore).

ALTER TABLE `fl_chat_connections`
ADD COLUMN `support_claimed_by_staff_id` INT(11) NULL DEFAULT NULL COMMENT 'When set, only this staff sees this support thread in Support Inbox' AFTER `updated_at`,
ADD INDEX `idx_support_claimed_by` (`support_claimed_by_staff_id`);
