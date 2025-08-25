-- Migration: 001_create_speed_tests_table.down.sql
-- Drop all tables

DROP TABLE IF EXISTS rate_limit_whitelist;
DROP TABLE IF EXISTS rate_limits;
DROP TABLE IF EXISTS api_keys;
DROP TABLE IF EXISTS speed_tests;
