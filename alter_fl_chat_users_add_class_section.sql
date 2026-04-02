-- Add class/section data for students in fl_chat_users.
-- Stores JSON array of {class_id, section_id, class_name, section_name} from student_session, classes, sections.
-- Run this once on your database.

ALTER TABLE `fl_chat_users`
ADD COLUMN `class_section_data` TEXT NULL DEFAULT NULL
COMMENT 'JSON array of {class_id, section_id, class_name, section_name} for students'
AFTER `user_type`;
