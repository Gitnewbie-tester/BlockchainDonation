const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'charity_chain_db',
  password: 'andrew',
  port: 5432,
});

async function checkDonations() {
  try {
    const email = 'ks@gmail.com';
    
    console.log(`\n🔍 Checking donations for: ${email}`);
    
    // Query donations directly by email (new approach)
    const donationsQuery = `
      SELECT tx_hash, donor_address, amount_wei, created_at
      FROM donations
      WHERE LOWER(donor_address) = LOWER($1)
      ORDER BY created_at DESC
    `;
    
    const donationsResult = await pool.query(donationsQuery, [email.toLowerCase()]);
    
    console.log(`\n📊 Found ${donationsResult.rows.length} donations:`);
    donationsResult.rows.forEach((d, i) => {
      console.log(`   ${i+1}. TX: ${d.tx_hash.substring(0, 10)}...`);
      console.log(`      Donor: ${d.donor_address}`);
      console.log(`      Amount: ${d.amount_wei}`);
      console.log(`      Date: ${d.created_at}`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkDonations();
