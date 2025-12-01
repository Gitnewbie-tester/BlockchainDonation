// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DonationRegistry
 * @dev Records donation events linking off-chain campaign data with on-chain transactions
 * This contract bridges your PostgreSQL database with the Sepolia blockchain
 */
contract DonationRegistry {
    // Event logged when a donation is made
    event DonationReceived(
        bytes32 indexed campaignIdHash,  // Hashed UUID from PostgreSQL
        address indexed donor,            // Donor's wallet address
        address indexed beneficiary,      // Charity's wallet address
        uint256 amount,                   // Donation amount in wei
        string receiptCid,                // IPFS CID of the receipt
        uint256 timestamp                 // Block timestamp
    );

    // Mapping to track total donations per campaign
    mapping(bytes32 => uint256) public campaignTotals;
    
    // Mapping to track donation count per donor
    mapping(address => uint256) public donorCounts;

    /**
     * @dev Records a donation and transfers ETH to the beneficiary
     * @param campaignId UUID of the campaign from PostgreSQL (will be hashed)
     * @param beneficiary Address of the charity receiving the donation
     * @param receiptCid IPFS CID of the donation receipt
     */
    function donate(
        string memory campaignId,
        address payable beneficiary,
        string memory receiptCid
    ) external payable {
        require(msg.value > 0, "Donation amount must be greater than 0");
        require(beneficiary != address(0), "Invalid beneficiary address");
        require(bytes(campaignId).length > 0, "Campaign ID is required");
        require(bytes(receiptCid).length > 0, "Receipt CID is required");

        // Hash the campaign ID for efficient indexing
        bytes32 campaignHash = keccak256(abi.encodePacked(campaignId));

        // Update campaign total
        campaignTotals[campaignHash] += msg.value;
        
        // Update donor count
        donorCounts[msg.sender] += 1;

        // Transfer ETH to beneficiary
        (bool success, ) = beneficiary.call{value: msg.value}("");
        require(success, "Transfer to beneficiary failed");

        // Emit event for off-chain tracking
        emit DonationReceived(
            campaignHash,
            msg.sender,
            beneficiary,
            msg.value,
            receiptCid,
            block.timestamp
        );
    }

    /**
     * @dev Get total donations for a campaign
     * @param campaignId Campaign UUID string
     * @return Total wei donated to this campaign
     */
    function getCampaignTotal(string memory campaignId) external view returns (uint256) {
        bytes32 campaignHash = keccak256(abi.encodePacked(campaignId));
        return campaignTotals[campaignHash];
    }

    /**
     * @dev Get total number of donations made by an address
     * @param donor Donor's wallet address
     * @return Number of donations
     */
    function getDonorCount(address donor) external view returns (uint256) {
        return donorCounts[donor];
    }
}
