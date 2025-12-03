const { ethers } = require('ethers');

/**
 * Calculate impact score for a user
 * Formula: Impact Score = (Total ETH Donated * 10) + (Referrals Count * 5)
 * 
 * @param {number} totalDonatedEth - Total ETH donated
 * @param {number} referralCount - Number of successful referrals
 * @returns {number} Calculated impact score
 */
function calculateImpactScore(totalDonatedEth, referralCount) {
  const donationPoints = totalDonatedEth * 10;
  const referralPoints = referralCount * 5;
  return donationPoints + referralPoints;
}

/**
 * Update user's impact score in database and award tokens
 * Token Distribution Rate: 1 Community Score = 10 CCT (CharityChain Tokens)
 * @param {Pool} pool - PostgreSQL pool instance
 * @param {string} userAddress - User's wallet address
 * @returns {Promise<object>} Updated impact score and tokens awarded
 */
async function updateImpactScore(pool, userAddress) {
  // Get user's total donated and referral count, plus current impact score
  const result = await pool.query(
    `SELECT total_donated_eth, referral_count, impact_score, reward_balance FROM users 
     WHERE LOWER(address) = LOWER($1)`,
    [userAddress]
  );
  
  if (result.rows.length === 0) {
    throw new Error('User not found');
  }
  
  const { total_donated_eth, referral_count, impact_score: oldImpactScore, reward_balance } = result.rows[0];
  const newImpactScore = calculateImpactScore(
    parseFloat(total_donated_eth || 0),
    parseInt(referral_count || 0)
  );
  
  // Calculate tokens to award based on impact score increase
  // Rate: 1 Community Score = 10 CCT
  const impactIncrease = Math.max(0, newImpactScore - parseFloat(oldImpactScore || 0));
  const tokensToAward = impactIncrease * 10;
  
  // Update the impact score and reward balance
  await pool.query(
    `UPDATE users 
     SET impact_score = $1, reward_balance = reward_balance + $2
     WHERE LOWER(address) = LOWER($3)`,
    [newImpactScore, tokensToAward, userAddress]
  );
  
  console.log(`💰 Token Distribution: User ${userAddress} earned ${tokensToAward} CCT (Impact: ${oldImpactScore} → ${newImpactScore})`);
  
  return {
    impactScore: newImpactScore,
    tokensAwarded: tokensToAward,
    newTokenBalance: parseFloat(reward_balance || 0) + tokensToAward
  };
}

/**
 * Update user's total donated amount
 * @param {Pool} pool - PostgreSQL pool instance
 * @param {string} userAddress - User's wallet address
 * @param {string} amountWei - Amount donated in wei
 * @returns {Promise<object>} Updated stats
 */
async function updateDonationStats(pool, userAddress, amountWei) {
  const amountEth = parseFloat(ethers.utils.formatEther(amountWei));
  
  // Update total donated
  await pool.query(
    `UPDATE users 
     SET total_donated_eth = total_donated_eth + $1
     WHERE LOWER(address) = LOWER($2)`,
    [amountEth, userAddress]
  );
  
  // Recalculate impact score
  const newImpactScore = await updateImpactScore(pool, userAddress);
  
  return {
    amountEth,
    newImpactScore
  };
}

/**
 * Check if user qualifies for reward and calculate amount
 * Rules:
 * - Impact score must be > 100
 * - Donation must be > 0.5 ETH
 * - Returns reward amount in CIC tokens (50 CIC for qualifying donations)
 * 
 * @param {number} impactScore - User's impact score
 * @param {string} donationAmountWei - Donation amount in wei
 * @returns {object} Reward eligibility and amount
 */
function checkRewardEligibility(impactScore, donationAmountWei) {
  const donationEth = parseFloat(ethers.utils.formatEther(donationAmountWei));
  
  const meetsImpactThreshold = impactScore > 100;
  const meetsDonationThreshold = donationEth > 0.5;
  
  const eligible = meetsImpactThreshold && meetsDonationThreshold;
  
  return {
    eligible,
    rewardAmount: eligible ? '50' : '0', // 50 CIC tokens
    reason: eligible 
      ? 'Qualified for bonus reward' 
      : !meetsImpactThreshold 
        ? 'Impact score must be greater than 100'
        : 'Donation must be greater than 0.5 ETH'
  };
}

/**
 * Get user's impact statistics
 * @param {Pool} pool - PostgreSQL pool instance
 * @param {string} userAddress - User's wallet address
 * @returns {Promise<object>} User's impact stats
 */
async function getImpactStats(pool, userAddress) {
  const result = await pool.query(
    `SELECT 
      impact_score,
      total_donated_eth,
      referral_count,
      reward_balance
    FROM users 
    WHERE LOWER(address) = LOWER($1)`,
    [userAddress]
  );
  
  if (result.rows.length === 0) {
    return {
      impactScore: 0,
      totalDonated: 0,
      referralCount: 0,
      rewardBalance: 0
    };
  }
  
  const row = result.rows[0];
  
  return {
    impactScore: parseFloat(row.impact_score || 0),
    totalDonated: parseFloat(row.total_donated_eth || 0),
    referralCount: parseInt(row.referral_count || 0),
    rewardBalance: parseFloat(row.reward_balance || 0)
  };
}

/**
 * Record reward minting in history
 * @param {Pool} pool - PostgreSQL pool instance
 * @param {string} userAddress - User's wallet address
 * @param {string} tokenAmount - Amount of tokens minted
 * @param {string} reason - Reason for minting
 * @param {string} txHash - Transaction hash (optional)
 * @returns {Promise<void>}
 */
async function recordRewardHistory(pool, userAddress, tokenAmount, reason, txHash = null) {
  await pool.query(
    `INSERT INTO rewards_history (user_address, token_amount, reason, tx_hash)
     VALUES ($1, $2, $3, $4)`,
    [userAddress, tokenAmount, reason, txHash]
  );
  
  // Update user's reward balance
  await pool.query(
    `UPDATE users 
     SET reward_balance = reward_balance + $1
     WHERE LOWER(address) = LOWER($2)`,
    [tokenAmount, userAddress]
  );
}

module.exports = {
  calculateImpactScore,
  updateImpactScore,
  updateDonationStats,
  checkRewardEligibility,
  getImpactStats,
  recordRewardHistory
};
