-- Allow OTP rows without an expiry (single-use only).
ALTER TABLE `mobile_app_device_transfer_otp` MODIFY `expires_at` datetime DEFAULT NULL;
