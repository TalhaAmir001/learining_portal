-- Add registered device columns to existing mobile_app_staff_device_otp tables.
ALTER TABLE `mobile_app_staff_device_otp`
  ADD COLUMN `registered_device_id` varchar(64) DEFAULT NULL COMMENT 'last authorized mobile device UUID' AFTER `otp_hash`,
  ADD COLUMN `registered_device_label` varchar(255) DEFAULT NULL COMMENT 'human-readable device name from app' AFTER `registered_device_id`,
  ADD COLUMN `device_last_seen_at` datetime DEFAULT NULL COMMENT 'last successful mobile login on registered device' AFTER `registered_device_label`;
