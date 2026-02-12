-- Add message type and image URL to fl_chat_messages for image messages
-- Run this once. Safe to run if columns already exist (ignore duplicate column errors).

ALTER TABLE `fl_chat_messages`
ADD COLUMN `message_type` ENUM('text', 'image') NOT NULL DEFAULT 'text' COMMENT 'Type of message' AFTER `message`,
ADD COLUMN `image_url` VARCHAR(512) NULL DEFAULT NULL COMMENT 'URL of attached image if message_type=image' AFTER `message_type`;
