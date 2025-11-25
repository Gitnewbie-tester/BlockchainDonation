const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'charity_chain_db',
  password: 'andrew',
  port: 5432,
});

async function fixBeneficiaries() {
  try {
    // Update all campaigns to use their owner_address as beneficiary if empty
    const result = await pool.query(`
      UPDATE campaigns 
      SET beneficiary_address = owner_address 
      WHERE beneficiary_address IS NULL OR beneficiary_address = ''
      RETURNING id, name, beneficiary_address
    `);

    console.log('\n=== UPDATED CAMPAIGNS ===\n');
    result.rows.forEach(row => {
      console.log(`✓ ${row.name}`);
      console.log(`  Beneficiary: ${row.beneficiary_address}`);
    });

    console.log(`\n${result.rows.length} campaigns updated!`);
    await pool.end();
  } catch (error) {
    console.error('Error:', error.message);
    await pool.end();
  }
}

fixBeneficiaries();
