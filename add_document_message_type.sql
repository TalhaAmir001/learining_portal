-- Add 'document' to message_type enum so chat can store document messages (URL in image_url column)
-- Run this once. Safe if column was created with add_message_type_and_image_url.sql.

ALTER TABLE `fl_chat_messages`
MODIFY COLUMN `message_type` ENUM('text', 'image', 'document') NOT NULL DEFAULT 'text' COMMENT 'Type of message';
