const hre = require("hardhat");

async function main() {
  console.log("🚀 Deploying Reward & Referral Contracts to Sepolia...\n");

  // Deploy ImpactCoin
  console.log("📝 Deploying ImpactCoin (CIC)...");
  const ImpactCoin = await hre.ethers.getContractFactory("ImpactCoin");
  const impactCoin = await ImpactCoin.deploy();
  await impactCoin.deployed();
  console.log("✅ ImpactCoin deployed to:", impactCoin.address);

  // Deploy DonationRegistryV2
  console.log("\n📝 Deploying DonationRegistryV2...");
  const DonationRegistry = await hre.ethers.getContractFactory("DonationRegistryV2");
  const registry = await DonationRegistry.deploy(impactCoin.address);
  await registry.deployed();
  console.log("✅ DonationRegistryV2 deployed to:", registry.address);

  // Grant MINTER_ROLE to DonationRegistry
  console.log("\n🔐 Granting MINTER_ROLE to DonationRegistryV2...");
  const MINTER_ROLE = await impactCoin.MINTER_ROLE();
  await impactCoin.grantRole(MINTER_ROLE, registry.address);
  console.log("✅ MINTER_ROLE granted");

  // Grant BURNER_ROLE to DonationRegistry
  console.log("🔐 Granting BURNER_ROLE to DonationRegistryV2...");
  const BURNER_ROLE = await impactCoin.BURNER_ROLE();
  await impactCoin.grantRole(BURNER_ROLE, registry.address);
  console.log("✅ BURNER_ROLE granted");

  console.log("\n" + "=".repeat(60));
  console.log("📋 DEPLOYMENT SUMMARY");
  console.log("=".repeat(60));
  console.log("ImpactCoin (CIC):     ", impactCoin.address);
  console.log("DonationRegistryV2:   ", registry.address);
  console.log("Network:              ", "Sepolia Testnet");
  console.log("Tokens per ETH:       ", "1000 CIC");
  console.log("Min donation reward:  ", "0.01 ETH");
  console.log("=".repeat(60));

  console.log("\n💾 Save these addresses to your backend .env file:");
  console.log(`IMPACT_COIN_ADDRESS=${impactCoin.address}`);
  console.log(`DONATION_REGISTRY_V2_ADDRESS=${registry.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
