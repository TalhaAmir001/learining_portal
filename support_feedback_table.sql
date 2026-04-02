-- Support feedback: text feedback from user in a support chat, saved against the admin (staff) who claimed the connection.
-- Run this in your MySQL database.

CREATE TABLE IF NOT EXISTS `fl_support_feedback` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `chat_connection_id` INT(11) NOT NULL COMMENT 'fl_chat_connections.id',
  `claimed_staff_id` INT(11) NULL DEFAULT NULL COMMENT 'Admin (staff) who claimed this support thread; feedback is attributed to them',
  `feedback_text` TEXT NOT NULL COMMENT 'Support feedback message from the user',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_chat_connection_id` (`chat_connection_id`),
  INDEX `idx_claimed_staff_id` (`claimed_staff_id`),
  INDEX `idx_created_at` (`created_at`),
  FOREIGN KEY (`chat_connection_id`) REFERENCES `fl_chat_connections`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Support feedback tickets from chat, attributed to admin in the chat';
