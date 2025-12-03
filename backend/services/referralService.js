const crypto = require('crypto');

/**
 * Generate a unique referral code
 * @returns {string} 6-character alphanumeric code
 */
function generateReferralCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclude similar looking chars
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

/**
 * Generate a unique referral code that doesn't exist in database
 * @param {Pool} pool - PostgreSQL pool instance
 * @returns {Promise<string>} Unique referral code
 */
async function generateUniqueReferralCode(pool) {
  let attempts = 0;
  const maxAttempts = 10;
  
  while (attempts < maxAttempts) {
    const code = generateReferralCode();
    
    // Check if code already exists
    const result = await pool.query(
      'SELECT referral_code FROM users WHERE referral_code = $1',
      [code]
    );
    
    if (result.rows.length === 0) {
      return code;
    }
    
    attempts++;
  }
  
  throw new Error('Failed to generate unique referral code after 10 attempts');
}

/**
 * Create or get referral code for a user by email
 * @param {Pool} pool - PostgreSQL pool instance
 * @param {string} email - User's email
 * @returns {Promise<string>} User's referral code
 */
async function getOrCreateReferralCodeByEmail(pool, email) {
  // Check if user already has a code
  const userResult = await pool.query(
    'SELECT referral_code FROM users WHERE LOWER(email) = LOWER($1)',
    [email]
  );
  
  if (userResult.rows.length === 0) {
    throw new Error('User not found');
  }
  
  if (userResult.rows[0].referral_code) {
    return userResult.rows[0].referral_code;
  }
  
  // Generate and assign new code
  const newCode = await generateUniqueReferralCode(pool);
  
  await pool.query(
    'UPDATE users SET referral_code = $1 WHERE LOWER(email) = LOWER($2)',
    [newCode, email]
  );
  
  return newCode;
}

/**
 * Create or get referral code for a user (legacy - by wallet address)
 * @param {Pool} pool - PostgreSQL pool instance
 * @param {string} userAddress - User's wallet address
 * @returns {Promise<string>} User's referral code
 */
async function getOrCreateReferralCode(pool, userAddress) {
  // Check if user already has a code
  const userResult = await pool.query(
    'SELECT referral_code FROM users WHERE LOWER(address) = LOWER($1)',
    [userAddress]
  );
  
  if (userResult.rows.length === 0) {
    throw new Error('User not found');
  }
  
  if (userResult.rows[0].referral_code) {
    return userResult.rows[0].referral_code;
  }
  
  // Generate and assign new code
  const newCode = await generateUniqueReferralCode(pool);
  
  await pool.query(
    'UPDATE users SET referral_code = $1 WHERE LOWER(address) = LOWER($2)',
    [newCode, userAddress]
  );
  
  return newCode;
}

/**
 * Bind a referrer to a new user
 * @param {Pool} pool - PostgreSQL pool instance
 * @param {string} userAddress - New user's wallet address
 * @param {string} referralCode - Referrer's referral code
 * @returns {Promise<object>} Result with success status
 */
async function bindReferral(pool, userAddress, referralCode) {
  // Find the referrer by code
  const referrerResult = await pool.query(
    'SELECT address FROM users WHERE referral_code = $1',
    [referralCode.toUpperCase()]
  );
  
  if (referrerResult.rows.length === 0) {
    throw new Error('Invalid referral code');
  }
  
  const referrerAddress = referrerResult.rows[0].address;
  
  // Check if user already has a referrer
  const userResult = await pool.query(
    'SELECT referred_by FROM users WHERE LOWER(address) = LOWER($1)',
    [userAddress]
  );
  
  if (userResult.rows.length === 0) {
    throw new Error('User not found');
  }
  
  if (userResult.rows[0].referred_by) {
    throw new Error('User already has a referrer');
  }
  
  // Cannot refer yourself
  if (referrerAddress.toLowerCase() === userAddress.toLowerCase()) {
    throw new Error('Cannot refer yourself');
  }
  
  // Update user's referrer
  await pool.query(
    'UPDATE users SET referred_by = $1 WHERE LOWER(address) = LOWER($2)',
    [referrerAddress, userAddress]
  );
  
  // Increment referrer's count
  await pool.query(
    'UPDATE users SET referral_count = referral_count + 1 WHERE LOWER(address) = LOWER($1)',
    [referrerAddress]
  );
  
  // Create referral record
  await pool.query(
    'INSERT INTO referrals (referrer_address, referee_address) VALUES ($1, $2)',
    [referrerAddress, userAddress]
  );
  
  return {
    success: true,
    referrerAddress,
    message: 'Referral linked successfully'
  };
}

/**
 * Get referral stats for a user by email
 * @param {Pool} pool - PostgreSQL pool instance
 * @param {string} email - User's email
 * @returns {Promise<object>} Referral statistics
 */
async function getReferralStatsByEmail(pool, email) {
  const result = await pool.query(
    `SELECT 
      referral_code,
      referred_by,
      referral_count,
      address,
      (SELECT COUNT(*) FROM referrals r 
       JOIN users u ON LOWER(r.referrer_address) = LOWER(u.address) 
       WHERE LOWER(u.email) = LOWER($1)) as actual_referral_count
    FROM users 
    WHERE LOWER(email) = LOWER($1)`,
    [email]
  );
  
  if (result.rows.length === 0) {
    return {
      referralCode: null,
      referredBy: null,
      referralCount: 0
    };
  }
  
  const row = result.rows[0];
  
  return {
    referralCode: row.referral_code,
    referredBy: row.referred_by,
    referralCount: row.actual_referral_count || 0
  };
}

/**
 * Get referral stats for a user
 * @param {Pool} pool - PostgreSQL pool instance
 * @param {string} userAddress - User's wallet address
 * @returns {Promise<object>} Referral statistics
 */
async function getReferralStats(pool, userAddress) {
  const result = await pool.query(
    `SELECT 
      referral_code,
      referred_by,
      referral_count,
      (SELECT COUNT(*) FROM referrals WHERE LOWER(referrer_address) = LOWER($1)) as actual_referral_count
    FROM users 
    WHERE LOWER(address) = LOWER($1)`,
    [userAddress]
  );
  
  if (result.rows.length === 0) {
    return {
      referralCode: null,
      referredBy: null,
      referralCount: 0
    };
  }
  
  const row = result.rows[0];
  
  return {
    referralCode: row.referral_code,
    referredBy: row.referred_by,
    referralCount: row.actual_referral_count || 0
  };
}

module.exports = {
  generateReferralCode,
  generateUniqueReferralCode,
  getOrCreateReferralCode,
  getOrCreateReferralCodeByEmail,
  getReferralStatsByEmail,
  bindReferral,
  getReferralStats
};
