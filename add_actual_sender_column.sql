-- Add actual_sender_staff_id to fl_chat_messages
-- When an admin sends in a support thread, we store their staff_id here so everyone
-- can see who sent each message (and so isCurrentUser is correct for each admin).

ALTER TABLE `fl_chat_messages`
ADD COLUMN `actual_sender_staff_id` INT(11) NULL DEFAULT NULL COMMENT 'When set, the staff_id of the admin who sent (support thread)' AFTER `chat_user_id`,
ADD INDEX `idx_actual_sender_staff_id` (`actual_sender_staff_id`);
