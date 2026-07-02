-- One current device-transfer OTP per active staff member (admin-visible code).
-- Auto-regenerated when used at mobile login. Staff accounts only.

CREATE TABLE IF NOT EXISTS `mobile_app_staff_device_otp` (
  `staff_id` int(11) UNSIGNED NOT NULL,
  `otp_code` char(6) NOT NULL COMMENT 'current code shown to admins',
  `otp_hash` varchar(255) NOT NULL COMMENT 'bcrypt hash for login verification',
  `registered_device_id` varchar(64) DEFAULT NULL COMMENT 'last authorized mobile device UUID',
  `registered_device_label` varchar(255) DEFAULT NULL COMMENT 'human-readable device name from app',
  `device_last_seen_at` datetime DEFAULT NULL COMMENT 'last successful mobile login on registered device',
  `last_used_at` datetime DEFAULT NULL COMMENT 'when the previous OTP code was consumed',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`staff_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
