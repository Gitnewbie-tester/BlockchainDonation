const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'charity_chain_db',
  password: 'andrew',
  port: 5432,
});

async function fixDonationAddresses() {
  console.log('🔧 Starting donation address fix...\n');
  
  // Show which user you want to fix donations for
  const targetEmail = 'ks@gmail.com'; // Change this to the user who made the donations
  const targetWallet = '0x29b8a765082b5a523a45643a874e824b5752e146'; // The wallet they used
  
  console.log(`🎯 Will update donations from wallet ${targetWallet} to email ${targetEmail}\n`);

  try {
    // First, let's see what we have in the database
    const usersQuery = 'SELECT email, address FROM users ORDER BY email';
    const usersResult = await pool.query(usersQuery);
    
    console.log('📋 Users in database:');
    usersResult.rows.forEach(user => {
      console.log(`   Email: ${user.email} → Address: ${user.address}`);
    });
    console.log('');

    const donationsQuery = 'SELECT tx_hash, donor_address, created_at FROM donations ORDER BY created_at DESC';
    const donationsResult = await pool.query(donationsQuery);
    
    console.log('📋 Donations in database:');
    donationsResult.rows.forEach(donation => {
      console.log(`   TX: ${donation.tx_hash.substring(0, 10)}..., Donor: ${donation.donor_address}`);
    });
    console.log('');

    // Now fix donations: Update all donations from targetWallet to use targetEmail
    let fixedCount = 0;
    
    for (const donation of donationsResult.rows) {
      const donorAddress = donation.donor_address.toLowerCase();
      
      // Skip if already an email
      if (donorAddress.includes('@')) {
        console.log(`✓ Donation ${donation.tx_hash.substring(0, 10)}... already uses email: ${donorAddress}`);
        continue;
      }

      // Check if this donation is from the target wallet
      if (donorAddress === targetWallet.toLowerCase()) {
        const updateQuery = `
          UPDATE donations 
          SET donor_address = $1 
          WHERE tx_hash = $2
        `;
        
        await pool.query(updateQuery, [targetEmail.toLowerCase(), donation.tx_hash]);
        console.log(`✅ Updated donation ${donation.tx_hash.substring(0, 10)}...: ${donorAddress.substring(0, 10)}... → ${targetEmail}`);
        fixedCount++;
      } else {
        console.log(`⏭️  Skipping donation ${donation.tx_hash.substring(0, 10)}... (different wallet: ${donorAddress.substring(0, 10)}...)`);
      }
    }

    console.log(`\n✅ Fixed ${fixedCount} donation(s)`);
    
    // Show final state
    const finalDonations = await pool.query(donationsQuery);
    console.log('\n📋 Donations after fix:');
    finalDonations.rows.forEach(donation => {
      console.log(`   TX: ${donation.tx_hash.substring(0, 10)}..., Donor: ${donation.donor_address}`);
    });

  } catch (error) {
    console.error('❌ Error fixing donations:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

fixDonationAddresses();
