const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'charity_chain_db',
  password: 'andrew',
  port: 5432,
});

async function checkCampaigns() {
  try {
    const result = await pool.query(`
      SELECT 
        id, 
        name, 
        beneficiary_address, 
        owner_address 
      FROM campaigns 
      ORDER BY id
    `);

    console.log('\n=== CAMPAIGNS IN DATABASE ===\n');
    
    if (result.rows.length === 0) {
      console.log('No campaigns found!');
    } else {
      result.rows.forEach(row => {
        console.log(`ID: ${row.id}`);
        console.log(`Name: ${row.name}`);
        console.log(`Beneficiary: ${row.beneficiary_address || '(empty)'}`);
        console.log(`Owner: ${row.owner_address || '(empty)'}`);
        console.log('---');
      });
    }

    await pool.end();
  } catch (error) {
    console.error('Error:', error.message);
    await pool.end();
  }
}

checkCampaigns();
