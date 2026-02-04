-- =====================================================
-- WebSocket Chat System Database Schema
-- =====================================================
-- This file contains SQL queries to create the necessary tables
-- for the WebSocket chat system.
-- 
-- Run these queries in your MySQL database connected to CodeIgniter
-- =====================================================

-- =====================================================
-- Table: chat_users
-- Description: Stores chat user information linked to staff or students
-- =====================================================
CREATE TABLE IF NOT EXISTS `fl_chat_users` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `staff_id` INT(11) NULL DEFAULT NULL COMMENT 'Reference to staff table',
  `student_id` INT(11) NULL DEFAULT NULL COMMENT 'Reference to student table',
  `user_type` ENUM('staff', 'student') NOT NULL DEFAULT 'staff' COMMENT 'Type of user',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_staff_id` (`staff_id`),
  INDEX `idx_student_id` (`student_id`),
  INDEX `idx_user_type` (`user_type`),
  UNIQUE KEY `unique_staff_user` (`staff_id`, `user_type`),
  UNIQUE KEY `unique_student_user` (`student_id`, `user_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Chat users table linking staff/students to chat system';

-- =====================================================
-- Table: chat_connections
-- Description: Stores chat connections between two users
-- =====================================================
  CREATE TABLE IF NOT EXISTS `fl_chat_connections` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `chat_user_one` INT(11) NOT NULL COMMENT 'First chat user ID (from chat_users table)',
    `chat_user_two` INT(11) NOT NULL COMMENT 'Second chat user ID (from chat_users table)',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_chat_user_one` (`chat_user_one`),
    INDEX `idx_chat_user_two` (`chat_user_two`),
    FOREIGN KEY (`chat_user_one`) REFERENCES `fl_chat_users`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`chat_user_two`) REFERENCES `fl_chat_users`(`id`) ON DELETE CASCADE,
    UNIQUE KEY `unique_connection` (`chat_user_one`, `chat_user_two`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Chat connections between two users';

-- =====================================================
-- Table: chat_messages
-- Description: Stores chat messages between users
-- =====================================================
CREATE TABLE IF NOT EXISTS `fl_chat_messages` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `chat_connection_id` INT(11) NOT NULL COMMENT 'Reference to chat_connections table',
  `chat_user_id` INT(11) NOT NULL COMMENT 'Receiver chat_user_id (from chat_users table)',
  `message` TEXT NOT NULL COMMENT 'Message content',
  `ip` VARCHAR(45) NULL DEFAULT NULL COMMENT 'IP address of sender',
  `time` INT(11) NULL DEFAULT NULL COMMENT 'Unix timestamp',
  `is_read` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Read status (0=unread, 1=read)',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_chat_connection_id` (`chat_connection_id`),
  INDEX `idx_chat_user_id` (`chat_user_id`),
  INDEX `idx_created_at` (`created_at`),
  INDEX `idx_is_read` (`is_read`),
  FOREIGN KEY (`chat_connection_id`) REFERENCES `fl_chat_connections`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`chat_user_id`) REFERENCES `fl_chat_users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Chat messages table';

-- =====================================================
-- Optional: Indexes for better performance
-- =====================================================
-- Additional composite indexes for common queries
CREATE INDEX `idx_connection_created` ON `fl_chat_messages` (`chat_connection_id`, `created_at`);
CREATE INDEX `idx_user_unread` ON `fl_chat_messages` (`chat_user_id`, `is_read`, `created_at`);

-- =====================================================
-- Notes:
-- =====================================================
-- 1. Make sure your staff_id and student_id columns match
--    the data types in your existing staff and student tables
-- 
-- 2. Adjust the foreign key constraints if your existing
--    tables use different column names or structures
-- 
-- 3. The chat_user_id in chat_messages represents the RECEIVER
--    of the message (as per the PHP server logic)
-- 
-- 4. The time column stores Unix timestamp, while created_at
--    stores MySQL timestamp for easier querying
-- 
-- 5. If you need to modify the schema, you can use:
--    ALTER TABLE statements or drop and recreate the tables
-- =====================================================
