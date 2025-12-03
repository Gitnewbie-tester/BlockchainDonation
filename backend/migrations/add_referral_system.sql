-- Migration: Add Referral and Reward System to Users Table
-- Date: 2025-12-02
-- Description: Adds columns to track referrals, impact scores, and reward balances

-- Add referral and impact score columns to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS referral_code VARCHAR(10) UNIQUE,
ADD COLUMN IF NOT EXISTS referred_by VARCHAR(60),
ADD COLUMN IF NOT EXISTS impact_score NUMERIC(10, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_donated_eth NUMERIC(18, 8) DEFAULT 0,
ADD COLUMN IF NOT EXISTS referral_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS reward_balance NUMERIC(18, 8) DEFAULT 0;

-- Create indexes for referral code lookups
CREATE INDEX IF NOT EXISTS idx_referral_code ON users(referral_code);
CREATE INDEX IF NOT EXISTS idx_referred_by ON users(referred_by);

-- Create rewards_history table to track token minting
CREATE TABLE IF NOT EXISTS rewards_history (
    id SERIAL PRIMARY KEY,
    user_address VARCHAR(60) NOT NULL,
    token_amount NUMERIC(18, 8) NOT NULL,
    reason VARCHAR(100),
    tx_hash VARCHAR(66),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_rewards_user ON rewards_history(user_address);

-- Create referrals table to track referral relationships
CREATE TABLE IF NOT EXISTS referrals (
    id SERIAL PRIMARY KEY,
    referrer_address VARCHAR(60) NOT NULL,
    referee_address VARCHAR(60) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(referee_address)
);

CREATE INDEX IF NOT EXISTS idx_referrer ON referrals(referrer_address);
CREATE INDEX IF NOT EXISTS idx_referee ON referrals(referee_address);

COMMIT;
