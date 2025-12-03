// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ImpactCoin.sol";

/**
 * @title DonationRegistryV2
 * @dev Manages donations and reward distribution
 * This is the upgraded version with reward system
 */
contract DonationRegistryV2 is Ownable, ReentrancyGuard {
    ImpactCoin public rewardToken;
    
    // Exchange rate: 1 ETH = X tokens
    // Default: 1 ETH = 1000 CIC tokens
    uint256 public tokensPerEth = 1000 * 10**18;
    
    // Minimum donation to earn rewards (0.01 ETH)
    uint256 public minDonationForReward = 0.01 ether;
    
    // Sponsor pool for token redemption
    uint256 public sponsorPool;
    
    struct Donation {
        address donor;
        address beneficiary;
        uint256 amount;
        uint256 timestamp;
        string campaignId;
        string receiptCid;
        uint256 rewardIssued;
    }
    
    mapping(address => uint256) public totalDonated;
    mapping(address => uint256) public rewardsEarned;
    Donation[] public donations;
    
    event DonationMade(
        address indexed donor,
        address indexed beneficiary,
        uint256 amount,
        uint256 timestamp,
        string campaignId,
        string receiptCid
    );
    
    event RewardMinted(
        address indexed user,
        uint256 tokenAmount,
        uint256 ethDonated
    );
    
    event TokensRedeemed(
        address indexed user,
        uint256 tokenAmount,
        uint256 ethValue,
        address charity
    );
    
    event SponsorPoolDeposit(address indexed sponsor, uint256 amount);
    
    constructor(address _rewardToken) {
        require(_rewardToken != address(0), "Invalid token address");
        rewardToken = ImpactCoin(_rewardToken);
    }
    
    /**
     * @dev Make a donation and earn rewards
     * @param beneficiary Address to receive the donation
     * @param campaignId Campaign identifier
     * @param receiptCid IPFS CID of the receipt
     */
    function donate(
        address payable beneficiary,
        string memory campaignId,
        string memory receiptCid
    ) external payable nonReentrant {
        require(msg.value > 0, "Donation must be greater than 0");
        require(beneficiary != address(0), "Invalid beneficiary");
        
        // Transfer donation to beneficiary
        (bool success, ) = beneficiary.call{value: msg.value}("");
        require(success, "Transfer failed");
        
        // Update donation tracking
        totalDonated[msg.sender] += msg.value;
        
        // Calculate reward tokens
        uint256 rewardAmount = 0;
        if (msg.value >= minDonationForReward) {
            rewardAmount = calculateReward(msg.value);
            
            // Mint reward tokens to donor
            rewardToken.mint(msg.sender, rewardAmount);
            rewardsEarned[msg.sender] += rewardAmount;
            
            emit RewardMinted(msg.sender, rewardAmount, msg.value);
        }
        
        // Record donation
        donations.push(Donation({
            donor: msg.sender,
            beneficiary: beneficiary,
            amount: msg.value,
            timestamp: block.timestamp,
            campaignId: campaignId,
            receiptCid: receiptCid,
            rewardIssued: rewardAmount
        }));
        
        emit DonationMade(
            msg.sender,
            beneficiary,
            msg.value,
            block.timestamp,
            campaignId,
            receiptCid
        );
    }
    
    /**
     * @dev Redeem tokens for ETH donation from sponsor pool
     * @param tokenAmount Amount of CIC tokens to redeem
     * @param charityAddress Charity to receive the ETH
     */
    function redeemAndDonate(
        uint256 tokenAmount,
        address payable charityAddress
    ) external nonReentrant {
        require(tokenAmount > 0, "Amount must be greater than 0");
        require(charityAddress != address(0), "Invalid charity address");
        require(rewardToken.balanceOf(msg.sender) >= tokenAmount, "Insufficient token balance");
        
        // Calculate ETH value
        uint256 ethValue = (tokenAmount * 1 ether) / tokensPerEth;
        require(sponsorPool >= ethValue, "Insufficient sponsor pool");
        
        // Transfer tokens from user to this contract
        require(
            rewardToken.transferFrom(msg.sender, address(this), tokenAmount),
            "Token transfer failed"
        );
        
        // Burn the tokens
        rewardToken.burn(tokenAmount);
        
        // Deduct from sponsor pool
        sponsorPool -= ethValue;
        
        // Send ETH to charity
        (bool success, ) = charityAddress.call{value: ethValue}("");
        require(success, "ETH transfer failed");
        
        emit TokensRedeemed(msg.sender, tokenAmount, ethValue, charityAddress);
    }
    
    /**
     * @dev Calculate reward tokens for a donation amount
     * @param donationAmount Donation in wei
     * @return Reward token amount (18 decimals)
     */
    function calculateReward(uint256 donationAmount) public view returns (uint256) {
        // Formula: tokens = (donation in ETH) * tokensPerEth
        return (donationAmount * tokensPerEth) / 1 ether;
    }
    
    /**
     * @dev Deposit ETH to sponsor pool
     */
    function depositToSponsorPool() external payable onlyOwner {
        require(msg.value > 0, "Must deposit ETH");
        sponsorPool += msg.value;
        emit SponsorPoolDeposit(msg.sender, msg.value);
    }
    
    /**
     * @dev Update token exchange rate
     * @param newRate New rate (tokens per 1 ETH)
     */
    function setTokensPerEth(uint256 newRate) external onlyOwner {
        require(newRate > 0, "Rate must be positive");
        tokensPerEth = newRate * 10**18;
    }
    
    /**
     * @dev Update minimum donation for rewards
     * @param newMin New minimum in wei
     */
    function setMinDonationForReward(uint256 newMin) external onlyOwner {
        minDonationForReward = newMin;
    }
    
    /**
     * @dev Get total number of donations
     */
    function getDonationCount() external view returns (uint256) {
        return donations.length;
    }
    
    /**
     * @dev Withdraw sponsor pool (emergency only)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");
    }
    
    receive() external payable {
        sponsorPool += msg.value;
        emit SponsorPoolDeposit(msg.sender, msg.value);
    }
}
