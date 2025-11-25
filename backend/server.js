const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const bodyParser = require('body-parser');

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
  if (address && address.trim().length > 0) {
    return address.trim();
  }
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

  return {
    totalDonatedEth: weiToEthString(total_wei),
    charitiesSupported: Number(charities_supported),
    impactScore,
    totalDonations: Number(total_donations),
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
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
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

app.post('/api/auth/register', async (req, res) => {
  const { address, name, email, phone, password } = req.body;
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

    const query = `
      INSERT INTO users (address, name, email, phone)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (address)
      DO UPDATE SET name = $2, email = $3, phone = $4
      RETURNING address, name, email, phone, created_at`;

    const { rows } = await pool.query(query, [
      normalizedAddress,
      name,
      normalizedEmail,
      phone || null,
    ]);

    const stats = await buildDashboardStats(normalizedAddress);
    res.json({ success: true, data: { user: rows[0], stats } });
  } catch (err) {
    console.error('Register error:', err.message);
    res.status(500).json({ error: 'Unable to register user.' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email } = req.body;
  if (!email) {
    return res.status(400).json({ error: 'Email is required.' });
  }

  try {
    const query = `
      SELECT address, name, email, phone
        FROM users
       WHERE email = $1
       LIMIT 1`;

    const { rows } = await pool.query(query, [email.toLowerCase()]);

    if (!rows.length) {
      return res.status(401).json({ error: 'User not found.' });
    }

    const user = rows[0];
    const stats = await buildDashboardStats(user.address);

    res.json({ success: true, data: { user, stats } });
  } catch (err) {
    console.error('Login error:', err.message);
    res.status(500).json({ error: 'Unable to login.' });
  }
});

// Dashboard stats
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
      owner_address || null,
      cover_image_cid || null,
      category || 'General',
      Boolean(verified),
      beneficiary_address || owner_address || null,
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

    // 1. Save Receipt Logic
    const receiptQuery = `
      INSERT INTO receipts (cid, size_bytes, pin_status, gateway_url)
      VALUES ($1, $2, 'pinned', $3)
      ON CONFLICT (cid) DO NOTHING`; // If receipt exists, skip
    await client.query(receiptQuery, [cid, size_bytes, gateway_url]);

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