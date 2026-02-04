-- =====================================================
-- Fix Foreign Key Constraints
-- =====================================================
-- This script fixes the foreign key constraints that reference
-- the wrong table names (chat_users instead of fl_chat_users)
-- 
-- Run this script on your database to fix the constraints
-- =====================================================

-- Drop existing foreign key constraints on fl_chat_connections
ALTER TABLE `fl_chat_connections` 
  DROP FOREIGN KEY IF EXISTS `fl_chat_connections_ibfk_1`,
  DROP FOREIGN KEY IF EXISTS `fl_chat_connections_ibfk_2`;

-- Recreate foreign key constraints with correct table names
ALTER TABLE `fl_chat_connections`
  ADD CONSTRAINT `fl_chat_connections_ibfk_1` 
    FOREIGN KEY (`chat_user_one`) REFERENCES `fl_chat_users`(`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fl_chat_connections_ibfk_2` 
    FOREIGN KEY (`chat_user_two`) REFERENCES `fl_chat_users`(`id`) ON DELETE CASCADE;

-- Drop existing foreign key constraints on fl_chat_messages
ALTER TABLE `fl_chat_messages`
  DROP FOREIGN KEY IF EXISTS `fl_chat_messages_ibfk_1`,
  DROP FOREIGN KEY IF EXISTS `fl_chat_messages_ibfk_2`;

-- Recreate foreign key constraints with correct table names
ALTER TABLE `fl_chat_messages`
  ADD CONSTRAINT `fl_chat_messages_ibfk_1` 
    FOREIGN KEY (`chat_connection_id`) REFERENCES `fl_chat_connections`(`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fl_chat_messages_ibfk_2` 
    FOREIGN KEY (`chat_user_id`) REFERENCES `fl_chat_users`(`id`) ON DELETE CASCADE;

-- =====================================================
-- Note: If the DROP FOREIGN KEY commands fail because
-- the constraint names are different, you can find the
-- actual constraint names using:
-- 
-- SHOW CREATE TABLE `fl_chat_connections`;
-- SHOW CREATE TABLE `fl_chat_messages`;
-- 
-- Then use the actual constraint names in the DROP commands
-- =====================================================
