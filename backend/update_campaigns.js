const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'charity_chain_db',
  password: 'andrew',
  port: 5432,
});

const BENEFICIARY_ADDRESS = '0x29B8a765082B5A523a45643A874e824b5752e146';

async function updateCampaigns() {
  try {
    const result = await pool.query(`
      UPDATE campaigns 
      SET 
        beneficiary_address = '${BENEFICIARY_ADDRESS}',
        owner_address = '${BENEFICIARY_ADDRESS}'
      WHERE 
        beneficiary_address IS NULL 
        OR beneficiary_address = '0x0000000000000000000000000000000000000000'
        OR owner_address = '0x0000000000000000000000000000000000000000'
    `);
    
    console.log(`✅ Updated ${result.rowCount} campaigns to use beneficiary address: ${BENEFICIARY_ADDRESS}`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Error updating campaigns:', error);
    process.exit(1);
  }
}

updateCampaigns();
