-- Add FCM token column to fl_chat_users table
-- This allows the WebSocket server to send push notifications when app is closed

ALTER TABLE `fl_chat_users` 
ADD COLUMN `fcm_token` VARCHAR(255) NULL DEFAULT NULL COMMENT 'Firebase Cloud Messaging token for push notifications' AFTER `user_type`,
ADD INDEX `idx_fcm_token` (`fcm_token`);

-- Optional: Create config table for FCM v1 API configuration
CREATE TABLE IF NOT EXISTS `fl_config` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `key_name` VARCHAR(255) NOT NULL COMMENT 'Configuration key name',
  `value` TEXT NOT NULL COMMENT 'Configuration value',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_key_name` (`key_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Application configuration table';

-- Insert FCM v1 API configuration (replace with your actual values)
-- Option 1: Store service account path and project ID in database
-- INSERT INTO fl_config (key_name, value) VALUES 
-- ('fcm_service_account_path', '/path/to/firebase-service-account.json'),
-- ('fcm_project_id', 'your-project-id');

-- Note: It's recommended to use environment variables or config files instead of database
-- for sensitive credentials like service account paths
