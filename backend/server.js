const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const bodyParser = require('body-parser');
const bcrypt = require('bcryptjs');
const { updateDonationStats } = require('./services/impactScoreService');

const SALT_ROUNDS = 10;

const app = express();

app.use(cors());
app.use(bodyParser.json());
app.use((req, _res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl}`);
  next();
});

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'charity_chain_db',
  password: 'andrew',
  port: 5432,
});

const PORT = process.env.PORT || 3000;
const DEFAULT_CAMPAIGN_IMAGE =
  'https://images.unsplash.com/photo-1455849318743-b2233052fcff?auto=format&fit=crop&w=1200&q=80';
const IPFS_GATEWAY = process.env.IPFS_GATEWAY || 'https://ipfs.io/ipfs/';

// Primary beneficiary wallet address for all donations
const BENEFICIARY_WALLET_ADDRESS = '0x29B8a765082B5A523a45643A874e824b5752e146';

const CAMPAIGN_FIELDS = `
  c.id,
  c.name,
  c.description,
  c.goal_eth,
  c.owner_address,
  c.cover_image_cid,
  c.category,
  c.verified,
  c.beneficiary_address,
  COALESCE(SUM(d.amount_wei), 0) AS total_wei,
  COUNT(d.tx_hash) AS supporter_count
`;

const CAMPAIGN_BASE_QUERY = `
  SELECT ${CAMPAIGN_FIELDS}
    FROM campaigns c
    LEFT JOIN donations d ON d.campaign_id = c.id
`;

const buildCampaignQuery = (whereClause = '', suffix = '') => `
  ${CAMPAIGN_BASE_QUERY}
  ${whereClause}
  GROUP BY c.id
  ${suffix}
`;

const resolveImageUrl = (value) => {
  if (!value || typeof value !== 'string') {
    return DEFAULT_CAMPAIGN_IMAGE;
  }

  const trimmed = value.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }

  const normalizedCid = trimmed.replace(/^ipfs:\/\//i, '');
  return `${IPFS_GATEWAY}${normalizedCid}`;
};

const WEI_PER_ETH = 1_000_000_000_000_000_000n;

const GMAIL_REGEX = /^[a-zA-Z0-9](?:[a-zA-Z0-9._%+-]{0,62}[a-zA-Z0-9])?@gmail\.com$/i;
const isValidGmail = (email) => typeof email === 'string' && GMAIL_REGEX.test(email.trim());
const isStrongPassword = (password) =>
  typeof password === 'string' &&
  password.length >= 8 &&
  /[A-Z]/.test(password) &&
  /[a-z]/.test(password) &&
  /[^A-Za-z0-9]/.test(password);

const normalizeAddress = (address, email) => {
  // Check if address is valid and not a placeholder
  const RECIPIENT_PLACEHOLDER = '0x4A9D9e820651c21947906F1BAA7f7f210e682b12';
  if (address && address.trim().length > 0 && address.trim() !== RECIPIENT_PLACEHOLDER) {
    return address.trim();
  }
  // For users without wallet, use email as unique identifier
  return email.toLowerCase();
};

const weiToEthString = (weiString) => {
  if (!weiString) return '0.000';
  try {
    const wei = BigInt(weiString);
    const whole = wei / WEI_PER_ETH;
    const remainder = wei % WEI_PER_ETH;
    const fraction = Number(remainder) / Number(WEI_PER_ETH);
    const eth = Number(whole) + fraction;
    return eth.toFixed(3);
  } catch (error) {
    const fallback = Number(weiString);
    return Number.isFinite(fallback) ? (fallback / 1e18).toFixed(3) : '0.000';
  }
};

const mapCampaignRow = (row) => {
  const goalEth = Number(row.goal_eth ?? 0);
  const raisedEth = parseFloat(weiToEthString(row.total_wei)) || 0;
  const safeGoal = Number.isFinite(goalEth) ? goalEth : 0;
  const safeRaised = Number.isFinite(raisedEth) ? raisedEth : 0;
  const rawProgress = safeGoal > 0 ? (safeRaised / safeGoal) * 100 : 0;
  const progressPercent = Number(Math.min(rawProgress, 100).toFixed(2));

  return {
    id: row.id,
    title: row.name,
    description: row.description || '',
    goalEth: Number(safeGoal.toFixed(3)),
    raisedEth: Number(safeRaised.toFixed(3)),
    backers: Number(row.supporter_count ?? 0),
    category: row.category || 'General',
    verified: Boolean(row.verified),
    ownerAddress: row.owner_address || '',
    beneficiaryAddress: row.beneficiary_address || row.owner_address || '',
    imageUrl: resolveImageUrl(row.cover_image_cid),
    progressPercent,
  };
};

const listCampaigns = async () => {
  const { rows } = await pool.query(buildCampaignQuery('', 'ORDER BY c.id DESC'));
  return rows.map(mapCampaignRow);
};

const getCampaignById = async (id) => {
  if (!id) return null;
  const { rows } = await pool.query(buildCampaignQuery('WHERE c.id = $1', 'LIMIT 1'), [id]);
  if (!rows.length) {
    return null;
  }
  return mapCampaignRow(rows[0]);
};

const buildDashboardStats = async (address) => {
  const [{ total_wei = '0', charities_supported = 0 }] = (
    await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) AS total_wei,
              COUNT(DISTINCT campaign_id) AS charities_supported
         FROM donations
        WHERE donor_address = $1`,
      [address]
    )
  ).rows;

  const [{ count: total_donations = 0 }] = (
    await pool.query(
      `SELECT COUNT(*)
         FROM donations
        WHERE donor_address = $1`,
      [address]
    )
  ).rows;

  const impactScore = Number(charities_supported) * 120 + Number(total_donations) * 15;

  // Get token balance (reward_balance) from users table
  // Query by address OR email since buildDashboardStats can receive either
  const userResult = await pool.query(
    'SELECT reward_balance FROM users WHERE LOWER(address) = LOWER($1) OR LOWER(email) = LOWER($1)',
    [address]
  );
  const tokenBalance = userResult.rows.length > 0 
    ? parseFloat(userResult.rows[0].reward_balance || 0)
    : 0;

  return {
    totalDonatedEth: weiToEthString(total_wei),
    charitiesSupported: Number(charities_supported),
    impactScore,
    totalDonations: Number(total_donations),
    tokenBalance: tokenBalance.toFixed(2),
  };
};

const FAQ_RESPONSES = [
  {
    keywords: ['how do i donate', 'make a donation', 'donate now'],
    answer:
      "Open any campaign, tap 'Donate Now', set your ETH amount, and confirm. We'll record the donation on-chain and email you a receipt immediately.",
  },
  {
    keywords: ['minimum donation', 'least amount'],
    answer: 'We recommend at least 0.001 ETH so gas fees stay lower than your gift.',
  },
  {
    keywords: ['wallet', 'metamask', 'connect'],
    answer:
      'Click Connect Wallet in the top right or from the donate drawer. We support MetaMask in the browser and will prompt you to approve the connection.',
  },
  {
    keywords: ['verified', 'trust', 'real charity'],
    answer:
      'Each charity uploads registration docs and is manually reviewed before the campaign goes live. You can see the verified badge on campaigns that pass.',
  },
  {
    keywords: ['receipt', 'history', 'track donation'],
    answer:
      'Every donation gets a blockchain transaction hash plus a downloadable receipt in your Donation History tab.',
  },
];

const findFaqResponse = (normalizedMessage) => {
  for (const item of FAQ_RESPONSES) {
    if (item.keywords.some((keyword) => normalizedMessage.includes(keyword))) {
      return item.answer;
    }
  }
  return null;
};

const describeTopCampaigns = async () => {
  const { rows } = await pool.query(
    `SELECT c.id,
            c.name,
            COALESCE(SUM(d.amount_wei), 0) AS total_wei,
            COUNT(d.tx_hash) AS supporters
       FROM campaigns c
  LEFT JOIN donations d ON d.campaign_id = c.id
   GROUP BY c.id
   ORDER BY total_wei DESC
      LIMIT 3`
  );

  if (!rows.length) {
    return 'We are still onboarding campaigns, so check back soon for featured causes.';
  }

  const summary = rows
    .map((row) => {
      const raised = weiToEthString(row.total_wei);
      const supporters = Number(row.supporters) || 0;
      return `${row.name} (${raised} ETH raised • ${supporters} supporters)`;
    })
    .join('; ');

  return `Here are the campaigns the community is backing right now: ${summary}. Pick one to see full details or donate instantly.`;
};

const describePlatformImpact = async () => {
  const [{
    total_wei = '0',
    donors = 0,
  }] = (
    await pool.query(
      `SELECT COALESCE(SUM(amount_wei), 0) AS total_wei,
              COUNT(DISTINCT donor_address) AS donors
         FROM donations`
    )
  ).rows;

  const totalEth = weiToEthString(total_wei);
  return `So far donors on CharityChain have contributed ${totalEth} ETH across ${donors} unique wallets. Every wei is traceable on-chain for full transparency.`;
};

const ensureSchema = async () => {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS campaigns (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      goal_eth NUMERIC(18, 6) DEFAULT 0,
      owner_address TEXT,
      cover_image_cid TEXT,
      category TEXT,
      verified BOOLEAN DEFAULT FALSE,
      beneficiary_address TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
  `);

  await pool.query('ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS category TEXT');
  await pool.query('ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT FALSE');
  await pool.query('ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS beneficiary_address TEXT');
  await pool.query('ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW()');

  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      address TEXT PRIMARY KEY,
      name TEXT,
      email TEXT UNIQUE,
      phone TEXT,
      password_hash TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
  `);
  
  // Add password_hash column if it doesn't exist (for existing databases)
  await pool.query(`
    ALTER TABLE users 
    ADD COLUMN IF NOT EXISTS password_hash TEXT;
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS receipts (
      cid TEXT PRIMARY KEY,
      size_bytes INTEGER,
      pin_status TEXT,
      gateway_url TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS donations (
      tx_hash TEXT PRIMARY KEY,
      donor_address TEXT NOT NULL,
      campaign_id TEXT,
      cid TEXT,
      amount_wei NUMERIC(78, 0) NOT NULL,
      status TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
  `);

  await pool.query('ALTER TABLE donations ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW()');
  
  // Migrate campaign_id from INTEGER to TEXT to support UUID
  await pool.query(`
    DO $$ 
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'donations' 
        AND column_name = 'campaign_id' 
        AND data_type = 'integer'
      ) THEN
        ALTER TABLE donations ALTER COLUMN campaign_id TYPE TEXT;
      END IF;
    END $$;
  `);

  // Drop foreign key constraint on donor_address if it exists
  await pool.query(`
    DO $$ 
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'donations_donor_address_fkey'
        AND table_name = 'donations'
      ) THEN
        ALTER TABLE donations DROP CONSTRAINT donations_donor_address_fkey;
      END IF;
    END $$;
  `);

  console.log('Database schema is up to date.');
  
  // Update existing campaigns with proper categories
  const { rows } = await pool.query('SELECT COUNT(*) as count FROM campaigns');
  const campaignCount = parseInt(rows[0].count);
  
  if (campaignCount === 0) {
    console.log('Seeding sample campaigns...');
  } else {
    console.log(`Found ${campaignCount} existing campaigns. Updating categories...`);
    // Update existing campaigns to have proper categories (PostgreSQL doesn't support LIMIT in UPDATE)
    await pool.query(`
      UPDATE campaigns SET category = 'Education' 
      WHERE id IN (SELECT id FROM campaigns WHERE category IS NULL OR category = 'General' LIMIT 2)
    `);
    await pool.query(`
      UPDATE campaigns SET category = 'Healthcare' 
      WHERE id IN (SELECT id FROM campaigns WHERE category = 'General' LIMIT 2)
    `);
  }
  
  // Always add diverse campaigns
  const sampleCampaigns = [
    { name: 'Hope Children\'s Home', description: 'Supporting orphaned children with education, shelter, and care', goal: 5.5, category: 'Children & Orphanages', verified: true },
    { name: 'Clean Water Initiative', description: 'Providing clean water access to rural communities', goal: 10.0, category: 'Community Development', verified: true },
    { name: 'Wildlife Conservation Fund', description: 'Protecting endangered species and their habitats', goal: 15.0, category: 'Environment', verified: true },
    { name: 'Medical Aid for All', description: 'Free healthcare services for underprivileged communities', goal: 8.0, category: 'Healthcare', verified: true },
    { name: 'School Building Project', description: 'Constructing schools in remote areas', goal: 20.0, category: 'Education', verified: true },
    { name: 'Flood Relief Fund', description: 'Emergency aid for flood victims', goal: 12.0, category: 'Disaster Relief', verified: true },
    { name: 'Animal Rescue Center', description: 'Rescuing and rehabilitating abandoned animals', goal: 6.0, category: 'Animal Welfare', verified: true },
    { name: 'Food Bank Support', description: 'Fighting hunger in urban areas', goal: 7.0, category: 'Poverty & Hunger', verified: true },
    { name: 'University Scholarship Fund', description: 'Helping underprivileged students attend university', goal: 25.0, category: 'Education', verified: true },
    { name: 'Mobile Health Clinic', description: 'Bringing medical care to remote villages', goal: 18.0, category: 'Healthcare', verified: true },
    { name: 'Earthquake Response Team', description: 'Rapid response for earthquake victims', goal: 30.0, category: 'Disaster Relief', verified: true },
    { name: 'Street Children Support', description: 'Providing shelter and education for street children', goal: 9.0, category: 'Children & Orphanages', verified: true },
    { name: 'Reforestation Project', description: 'Planting trees to combat climate change', goal: 14.0, category: 'Environment', verified: true },
    { name: 'Homeless Shelter', description: 'Safe shelter and meals for the homeless', goal: 11.0, category: 'Poverty & Hunger', verified: true },
    { name: 'Dog Rescue Sanctuary', description: 'Rescuing and rehoming abandoned dogs', goal: 7.5, category: 'Animal Welfare', verified: true },
    { name: 'Rural Infrastructure', description: 'Building roads and bridges in rural areas', goal: 22.0, category: 'Community Development', verified: true },
  ];
  
  for (const camp of sampleCampaigns) {
    // Check if campaign already exists
    const existing = await pool.query('SELECT id FROM campaigns WHERE name = $1', [camp.name]);
    if (existing.rows.length === 0) {
      await pool.query(
        'INSERT INTO campaigns (name, description, goal_eth, category, verified, owner_address, beneficiary_address) VALUES ($1, $2, $3, $4, $5, $6, $7)',
        [camp.name, camp.description, camp.goal, camp.category, camp.verified, BENEFICIARY_WALLET_ADDRESS, BENEFICIARY_WALLET_ADDRESS]
      );
    }
  }
  console.log('Campaign categories updated and sample campaigns added.');
};

app.get('/', (_req, res) => {
  res.send('CharityChain Backend is Running!');
});

app.get('/api/campaigns', async (_req, res) => {
  try {
    const campaigns = await listCampaigns();
    res.json({ success: true, data: campaigns });
  } catch (error) {
    console.error('Fetch campaigns error:', error.message);
    res.status(500).json({ error: 'Unable to load campaigns.' });
  }
});

app.get('/api/campaigns/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const campaign = await getCampaignById(id);
    if (!campaign) {
      return res.status(404).json({ error: 'Campaign not found.' });
    }
    res.json({ success: true, data: campaign });
  } catch (error) {
    console.error('Fetch campaign error:', error.message);
    res.status(500).json({ error: 'Unable to load campaign.' });
  }
});

app.post('/api/chat', async (req, res) => {
  const { message } = req.body;
  if (!message || typeof message !== 'string') {
    return res.status(400).json({ error: 'Message is required.' });
  }

  const normalized = message.toLowerCase().trim();

  try {
    if (normalized.includes('top') && normalized.includes('campaign')) {
      const answer = await describeTopCampaigns();
      return res.json({ answer, isTrained: true, strategy: 'top_campaigns' });
    }

    if (normalized.includes('stats') || normalized.includes('impact') || normalized.includes('transparent')) {
      const answer = await describePlatformImpact();
      return res.json({ answer, isTrained: true, strategy: 'platform_impact' });
    }

    const faq = findFaqResponse(normalized);
    if (faq) {
      return res.json({ answer: faq, isTrained: true, strategy: 'faq' });
    }

    const stats = await describePlatformImpact();
    return res.json({
      answer:
        "I'm still learning, but here's something helpful: " +
        stats +
        ' Ask me about donations, wallets, verification, or say "top campaigns" to discover where others are giving.',
      isTrained: false,
    });
  } catch (error) {
    console.error('Chat assistant error:', error.message);
    return res.status(500).json({ error: 'Assistant is unavailable right now.' });
  }
});

// Update user information
app.post('/api/user/update', async (req, res) => {
  const { address, name, email, phone } = req.body;
  
  if (!address || !name || !email) {
    return res.status(400).json({ error: 'Address, name, and email are required.' });
  }

  try {
    const query = `
      UPDATE users 
      SET name = $1, email = $2, phone = $3
      WHERE address = $4
      RETURNING *`;
    
    const { rows } = await pool.query(query, [name, email, phone || null, address]);
    
    if (rows.length === 0) {
      return res.status(404).json({ error: 'User not found.' });
    }

    res.json({ success: true, user: rows[0] });
  } catch (err) {
    console.error('Update user error:', err.message);
    res.status(500).json({ error: 'Unable to update user information.' });
  }
});

app.post('/api/auth/register', async (req, res) => {
  const { address, name, email, phone, password, referralCode } = req.body;
  if (!email || !name || !password) {
    return res.status(400).json({ error: 'Name, email, and password are required.' });
  }

  if (!isValidGmail(email)) {
    return res.status(400).json({ error: 'Email must be a valid @gmail.com address.' });
  }

  if (!isStrongPassword(password)) {
    return res.status(400).json({
      error: 'Password must be at least 8 characters with upper, lower, and special characters.',
    });
  }

  try {
    const normalizedEmail = email.toLowerCase();
    const normalizedAddress = normalizeAddress(address, normalizedEmail);

    // If referral code provided, validate it first
    let referrerAddress = null;
    if (referralCode && referralCode.trim().length > 0) {
      const referrerResult = await pool.query(
        'SELECT address FROM users WHERE referral_code = $1',
        [referralCode.trim().toUpperCase()]
      );
      
      if (referrerResult.rows.length === 0) {
        return res.status(400).json({ error: 'Invalid referral code' });
      }
      
      referrerAddress = referrerResult.rows[0].address;
    }

    // Hash the password before storing
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    
    const query = `
      INSERT INTO users (address, name, email, phone, password_hash, referred_by)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (address)
      DO UPDATE SET name = $2, email = $3, phone = $4, password_hash = $5
      RETURNING address, name, email, phone, created_at, referred_by`;

    const { rows } = await pool.query(query, [
      normalizedAddress,
      name,
      normalizedEmail,
      phone || null,
      passwordHash,
      referrerAddress,
    ]);

    // If referral code was used, increment referrer's count and create referral record
    if (referrerAddress) {
      await pool.query(
        'UPDATE users SET referral_count = referral_count + 1 WHERE address = $1',
        [referrerAddress]
      );
      
      await pool.query(
        'INSERT INTO referrals (referrer_address, referee_address) VALUES ($1, $2)',
        [referrerAddress, normalizedAddress]
      );
      
      console.log(`✅ User ${normalizedEmail} registered with referral code: ${referralCode}`);
    }

    const stats = await buildDashboardStats(normalizedAddress);
    res.json({ success: true, data: { user: rows[0], stats } });
  } catch (err) {
    console.error('Register error:', err.message);
    res.status(500).json({ error: 'Unable to register user.' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required.' });
  }

  try {
    const query = `
      SELECT address, name, email, phone, password_hash
        FROM users
       WHERE email = $1
       LIMIT 1`;

    const { rows } = await pool.query(query, [email.toLowerCase()]);

    if (!rows.length) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const user = rows[0];
    
    // Verify password
    const passwordMatch = await bcrypt.compare(password, user.password_hash || '');
    
    if (!passwordMatch) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }
    
    // Remove password_hash from response
    delete user.password_hash;
    
    const stats = await buildDashboardStats(user.address);

    res.json({ success: true, data: { user, stats } });
  } catch (err) {
    console.error('Login error:', err.message);
    res.status(500).json({ error: 'Unable to login.' });
  }
});

// Get beneficiary wallet address
app.get('/api/beneficiary-address', async (req, res) => {
  res.json({ success: true, address: BENEFICIARY_WALLET_ADDRESS });
});

// Dashboard stats by address (legacy)
app.get('/api/dashboard/:address', async (req, res) => {
  const { address } = req.params;
  if (!address) {
    return res.status(400).json({ error: 'Address is required.' });
  }

  try {
    const stats = await buildDashboardStats(address);
    res.json({ success: true, data: stats });
  } catch (error) {
    console.error('Dashboard stats error:', error.message);
    res.status(500).json({ error: 'Unable to fetch dashboard stats.' });
  }
});

// Dashboard stats by email (preferred)
app.get('/api/dashboard/by-email/:email', async (req, res) => {
  const { email } = req.params;
  if (!email) {
    return res.status(400).json({ error: 'Email is required.' });
  }

  try {
    // Query donations directly by email (since we now store email as donor_address)
    const stats = await buildDashboardStats(email.toLowerCase());
    res.json({ success: true, data: stats });
  } catch (error) {
    console.error('Dashboard stats by email error:', error.message);
    res.status(500).json({ error: 'Unable to fetch dashboard stats.' });
  }
});

// Campaign creation
app.post('/api/campaign', async (req, res) => {
  const {
    name,
    description,
    goal_eth,
    owner_address,
    cover_image_cid,
    category,
    verified,
    beneficiary_address,
  } = req.body || {};

  if (!name || typeof name !== 'string') {
    return res.status(400).json({ error: 'Campaign name is required.' });
  }

  try {
    const goalValue = Number(goal_eth ?? 0);
    const insertQuery = `
      INSERT INTO campaigns (name, description, goal_eth, owner_address, cover_image_cid, category, verified, beneficiary_address)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING id`;

    const { rows } = await pool.query(insertQuery, [
      name,
      description || '',
      Number.isFinite(goalValue) ? goalValue : 0,
      owner_address || BENEFICIARY_WALLET_ADDRESS,
      cover_image_cid || null,
      category || 'General',
      Boolean(verified),
      BENEFICIARY_WALLET_ADDRESS, // Always use the configured beneficiary address
    ]);

    const campaign = await getCampaignById(rows[0].id);
    res.json({ success: true, data: campaign || { id: rows[0].id, title: name } });
  } catch (err) {
    console.error('Create campaign error:', err.message);
    res.status(500).json({ error: 'Unable to create campaign.' });
  }
});

// D. Record Donation (Matches 'receipts' AND 'donations' tables)
// This is a TRANSACTION. It saves the Receipt first, then the Donation.
app.post('/api/donate', async (req, res) => {
  const { 
    tx_hash, donor_address, campaign_id, amount_wei, // Donation Data
    cid, size_bytes, gateway_url                     // Receipt Data
  } = req.body;

  const client = await pool.connect();

  try {
    await client.query('BEGIN'); // Start a "Safety Box" transaction

    // 1. Save Receipt Logic (skip if it's a local-only receipt)
    if (!cid.startsWith('local-receipt-')) {
      const receiptQuery = `
        INSERT INTO receipts (cid, size_bytes, pin_status, gateway_url)
        VALUES ($1, $2, 'pinned', $3)
        ON CONFLICT (cid) DO NOTHING`; // If receipt exists, skip
      await client.query(receiptQuery, [cid, size_bytes, gateway_url]);
    } else {
      console.log('⚠️ Skipping IPFS receipt storage for local receipt:', cid);
    }

    // 2. Save Donation Logic
    const donationQuery = `
      INSERT INTO donations (
        tx_hash, donor_address, campaign_id, cid, amount_wei, status
      )
      VALUES ($1, $2, $3, $4, $5, 'Success')
      RETURNING *`;
    
    const result = await client.query(donationQuery, [
      tx_hash, donor_address, campaign_id, cid, amount_wei
    ]);

    // 3. Update user's total donated and impact score
    await updateDonationStats(pool, donor_address, amount_wei);

    await client.query('COMMIT'); // Save everything permanently
    res.json({ success: true, data: result.rows[0] });

  } catch (err) {
    await client.query('ROLLBACK'); // Undo everything if error occurs
    console.error("Transaction Failed:", err.message);
    res.status(500).json({ error: "Failed to record donation" });
  } finally {
    client.release();
  }
});

// E. Get Donation History for a Wallet Address
// Returns all donations made by a specific wallet address with campaign and receipt details
app.get('/api/donations/:address', async (req, res) => {
  try {
    const { address } = req.params;
    
    console.log(`📜 Fetching donation history for: ${address}`);

    // Query to join donations with campaigns and receipts
    const query = `
      SELECT 
        d.tx_hash,
        d.amount_wei,
        d.created_at,
        d.status,
        c.name as campaign_name,
        c.beneficiary_address,
        r.cid,
        r.gateway_url,
        r.size_bytes
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      LEFT JOIN receipts r ON d.cid = r.cid
      WHERE LOWER(d.donor_address) = LOWER($1)
      ORDER BY d.created_at DESC
    `;

    const result = await pool.query(query, [address]);
    
    console.log(`✅ Found ${result.rows.length} donations for ${address}`);
    
    res.json(result.rows);
  } catch (err) {
    console.error('❌ Error fetching donation history:', err.message);
    res.status(500).json({ 
      error: 'Failed to fetch donation history',
      details: err.message 
    });
  }
});

// F. Get Donation History by Email
// Returns all donations made by a user identified by email
app.get('/api/donations/by-email/:email', async (req, res) => {
  try {
    const { email } = req.params;
    
    console.log(`📜 Fetching donation history for user: ${email}`);

    // Query donations directly by email (since we now store email as donor_address)
    const query = `
      SELECT 
        d.tx_hash,
        d.amount_wei,
        d.created_at,
        d.status,
        c.name as campaign_name,
        c.beneficiary_address,
        r.cid,
        r.gateway_url,
        r.size_bytes
      FROM donations d
      JOIN campaigns c ON d.campaign_id = c.id
      LEFT JOIN receipts r ON d.cid = r.cid
      WHERE LOWER(d.donor_address) = LOWER($1)
      ORDER BY d.created_at DESC
    `;

    const result = await pool.query(query, [email.toLowerCase()]);
    
    console.log(`✅ Found ${result.rows.length} donations for ${email}`);
    
    res.json({ success: true, data: result.rows });
  } catch (err) {
    console.error('❌ Error fetching donation history by email:', err.message);
    res.status(500).json({ 
      error: 'Failed to fetch donation history',
      details: err.message 
    });
  }
});

// --- REFERRAL & REWARD SYSTEM ENDPOINTS ---

const referralService = require('./services/referralService');
const impactScoreService = require('./services/impactScoreService');

// Generate or get referral code for user
app.post('/api/user/generate-referral', async (req, res) => {
  try {
    const { userAddress, email } = req.body;
    
    // Prioritize email-based generation
    if (email) {
      const referralCode = await referralService.getOrCreateReferralCodeByEmail(pool, email);
      return res.json({
        success: true,
        referralCode
      });
    }
    
    // Fallback to wallet address
    if (!userAddress) {
      return res.status(400).json({ error: 'email or userAddress is required' });
    }
    
    const referralCode = await referralService.getOrCreateReferralCode(pool, userAddress);
    
    res.json({
      success: true,
      referralCode
    });
  } catch (err) {
    console.error('❌ Error generating referral code:', err.message);
    res.status(500).json({
      error: 'Failed to generate referral code',
      details: err.message
    });
  }
});

// Get user's impact statistics
app.get('/api/user/impact-stats', async (req, res) => {
  try {
    const { address, email } = req.query;
    
    // Prioritize email-based lookup
    if (email) {
      // Get user by email first to get wallet address
      const userResult = await pool.query(
        'SELECT address FROM users WHERE LOWER(email) = LOWER($1)',
        [email]
      );
      
      if (userResult.rows.length === 0) {
        return res.status(404).json({ error: 'User not found' });
      }
      
      const userAddress = userResult.rows[0].address || '';
      
      // Get impact stats (if wallet connected)
      const impactStats = userAddress 
        ? await impactScoreService.getImpactStats(pool, userAddress)
        : { impactScore: 0, totalDonated: 0, rewardBalance: 0 };
      
      // Get referral stats by email
      const referralStats = await referralService.getReferralStatsByEmail(pool, email);
      
      return res.json({
        success: true,
        data: {
          impactScore: impactStats.impactScore,
          totalDonated: impactStats.totalDonated,
          referralCount: referralStats.referralCount,
          rewardBalance: impactStats.rewardBalance,
          referralCode: referralStats.referralCode,
          referredBy: referralStats.referredBy
        }
      });
    }
    
    // Fallback to wallet address
    if (!address) {
      return res.status(400).json({ error: 'email or address query parameter is required' });
    }
    
    // Get impact stats
    const impactStats = await impactScoreService.getImpactStats(pool, address);
    
    // Get referral stats
    const referralStats = await referralService.getReferralStats(pool, address);
    
    res.json({
      success: true,
      data: {
        impactScore: impactStats.impactScore,
        totalDonated: impactStats.totalDonated,
        referralCount: referralStats.referralCount,
        rewardBalance: impactStats.rewardBalance,
        referralCode: referralStats.referralCode,
        referredBy: referralStats.referredBy
      }
    });
  } catch (err) {
    console.error('❌ Error fetching impact stats:', err.message);
    res.status(500).json({
      error: 'Failed to fetch impact stats',
      details: err.message
    });
  }
});

// Claim referral (link user to referrer)
app.post('/api/referral/claim', async (req, res) => {
  try {
    const { userAddress, referralCode } = req.body;
    
    if (!userAddress || !referralCode) {
      return res.status(400).json({ 
        error: 'userAddress and referralCode are required' 
      });
    }
    
    const result = await referralService.bindReferral(pool, userAddress, referralCode);
    
    res.json({
      success: true,
      message: result.message,
      referrerAddress: result.referrerAddress
    });
  } catch (err) {
    console.error('❌ Error claiming referral:', err.message);
    res.status(400).json({
      error: 'Failed to claim referral',
      details: err.message
    });
  }
});

// Get referral code details (for showing who owns a code)
app.get('/api/referral/validate/:code', async (req, res) => {
  try {
    const { code } = req.params;
    
    const result = await pool.query(
      'SELECT wallet_address FROM users WHERE referral_code = $1',
      [code.toUpperCase()]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        valid: false,
        message: 'Invalid referral code'
      });
    }
    
    res.json({
      success: true,
      valid: true,
      referrerAddress: result.rows[0].wallet_address
    });
  } catch (err) {
    console.error('❌ Error validating referral code:', err.message);
    res.status(500).json({
      error: 'Failed to validate referral code',
      details: err.message
    });
  }
});

// Get reward history for user
app.get('/api/user/reward-history', async (req, res) => {
  try {
    const { address } = req.query;
    
    if (!address) {
      return res.status(400).json({ error: 'address query parameter is required' });
    }
    
    const result = await pool.query(
      `SELECT * FROM rewards_history 
       WHERE LOWER(user_address) = LOWER($1) 
       ORDER BY created_at DESC 
       LIMIT 50`,
      [address]
    );
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error('❌ Error fetching reward history:', err.message);
    res.status(500).json({
      error: 'Failed to fetch reward history',
      details: err.message
    });
  }
});

// Get detailed referral list (who used your code and how much they donated)
app.get('/api/user/referrals', async (req, res) => {
  try {
    const { address, email } = req.query;
    
    if (!address && !email) {
      return res.status(400).json({ error: 'address or email query parameter is required' });
    }
    
    let referrerAddress;
    
    // If email provided, get the address from users table
    if (email) {
      const userResult = await pool.query(
        'SELECT address FROM users WHERE LOWER(email) = LOWER($1)',
        [email]
      );
      if (userResult.rows.length === 0) {
        return res.json({
          success: true,
          data: [],
          totalReferrals: 0
        });
      }
      referrerAddress = userResult.rows[0].address;
    } else {
      referrerAddress = address;
    }
    
    // Get list of users who were referred by this address
    const result = await pool.query(
      `SELECT 
        u.address as referee_address,
        u.email as referee_email,
        u.name as referee_name,
        COALESCE(
          (SELECT SUM(CAST(d.amount_wei AS NUMERIC)) / 1000000000000000000 
           FROM donations d 
           WHERE LOWER(d.donor_address) = LOWER(u.address) 
           AND d.status IN ('Success', 'confirmed')),
          0
        ) as total_donated_eth,
        u.created_at as referred_at,
        COALESCE(
          (SELECT COUNT(*) FROM donations d 
           WHERE LOWER(d.donor_address) = LOWER(u.address) 
           AND d.status IN ('Success', 'confirmed')),
          0
        ) as donation_count
      FROM users u
      WHERE LOWER(u.referred_by) = LOWER($1)
      ORDER BY u.created_at DESC`,
      [referrerAddress]
    );
    
    res.json({
      success: true,
      data: result.rows,
      totalReferrals: result.rows.length
    });
  } catch (err) {
    console.error('❌ Error fetching referral list:', err.message);
    res.status(500).json({
      error: 'Failed to fetch referral list',
      details: err.message
    });
  }
});

// --- 4. START SERVER ---
ensureSchema()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  })
  .catch((error) => {
    console.error('Failed to initialize database schema:', error.message);
    process.exit(1);
  });