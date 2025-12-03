const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'charity_chain_db',
  password: 'andrew',
  port: 5432
});

async function checkDatabase() {
  try {
    // Check table columns
    const columns = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      ORDER BY ordinal_position
    `);
    
    console.log('\n=== USERS TABLE COLUMNS ===');
    columns.rows.forEach(row => {
      console.log(`${row.column_name}: ${row.data_type}`);
    });
    
    // Check if referral columns exist
    const referralColumns = columns.rows.filter(row => 
      row.column_name.includes('referral') || 
      row.column_name.includes('impact') || 
      row.column_name.includes('reward')
    );
    
    console.log('\n=== REFERRAL/REWARD COLUMNS ===');
    if (referralColumns.length === 0) {
      console.log('❌ NO referral/reward columns found!');
      console.log('⚠️  Migration has NOT been run!');
    } else {
      console.log('✅ Found columns:');
      referralColumns.forEach(row => {
        console.log(`  - ${row.column_name}: ${row.data_type}`);
      });
    }
    
    // Check a sample user's referral code
    const sampleUser = await pool.query(`
      SELECT email, referral_code, referred_by, impact_score, referral_count 
      FROM users 
      WHERE email = 'mohguanseng@gmail.com'
      LIMIT 1
    `);
    
    console.log('\n=== SAMPLE USER DATA ===');
    if (sampleUser.rows.length > 0) {
      console.log('User:', sampleUser.rows[0]);
    } else {
      console.log('User mohguanseng@gmail.com not found');
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkDatabase();
