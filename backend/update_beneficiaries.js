const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'charity_chain_db',
  password: 'andrew',
  port: 5432,
});

async function updateBeneficiaries() {
  try {
    const beneficiaryAddress = '0x4A9D9e820651c21947906F1BAA7f7f210e682b12';
    
    const result = await pool.query(`
      UPDATE campaigns 
      SET beneficiary_address = $1
      RETURNING id, name, beneficiary_address
    `, [beneficiaryAddress]);

    console.log('\n=== UPDATED ALL CAMPAIGNS ===\n');
    result.rows.forEach(row => {
      console.log(`✓ ${row.name}`);
      console.log(`  ID: ${row.id}`);
      console.log(`  Beneficiary: ${row.beneficiary_address}`);
      console.log('---');
    });

    console.log(`\n${result.rows.length} campaigns updated successfully!`);
    await pool.end();
  } catch (error) {
    console.error('Error:', error.message);
    await pool.end();
  }
}

updateBeneficiaries();
