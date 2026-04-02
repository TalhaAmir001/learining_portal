-- Add class, section and recipient students to daily feedback.
-- Run this once on your database.

ALTER TABLE `fl_daily_feedback`
ADD COLUMN `class_id` INT(11) NULL DEFAULT NULL AFTER `voice_url`,
ADD COLUMN `section_id` INT(11) NULL DEFAULT NULL AFTER `class_id`,
ADD COLUMN `recipient_student_ids` TEXT NULL DEFAULT NULL COMMENT 'JSON array of student_id from fl_chat_users' AFTER `section_id`;
