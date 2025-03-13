// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract VegaVoting is Ownable, ERC721URIStorage {
    using SafeERC20 for IERC20;
    
    IERC20 public vegaVoteToken;
    uint256 public nextVoteId;
    uint256 public nextNftId;

    struct Vote {
        string description;
        uint256 deadline;
        uint256 threshold;
        uint256 yesVotes;
        uint256 noVotes;
        bool finalized;
    }
    
    struct Stake {
        uint256 amount;
        uint256 period;
        uint256 votingPower;
        uint256 startTime;
        bool active;
    }

    mapping(uint256 => Vote) public votes;
    mapping(address => Stake[]) public stakes;
    mapping(address => mapping(uint256 => bool)) public hasVoted;
    
    event VoteCreated(uint256 indexed voteId, string description, uint256 deadline, uint256 threshold);
    event Voted(address indexed voter, uint256 indexed voteId, bool choice, uint256 power);
    event VoteFinalized(uint256 indexed voteId, bool passed);
    event NFTMinted(uint256 indexed nftId, string metadataURI);
    event TokensUnstaked(address indexed user, uint256 amount);

    constructor(address vegaToken) ERC721("VotingResult", "VGVT") Ownable(msg.sender) {
        vegaVoteToken = IERC20(vegaToken);
    }

    function stakeTokens(uint256 amount, uint256 period) external {
        require(period >= 0 && period <= 4 days * 365 + 1 days, "Invalid staking period");
        require(vegaVoteToken.transferFrom(msg.sender, address(this), amount), "Stake failed");
        
        uint256 votingPower = amount + period ** 2;
        stakes[msg.sender].push(Stake(amount, period, votingPower, block.timestamp, true));
    }

    function unstakeTokens(uint256 stakeIndex) external {
        require(stakeIndex < stakes[msg.sender].length, "Invalid stake index");
        Stake storage userStake = stakes[msg.sender][stakeIndex];
        require(userStake.active, "Stake already unstaked");
        require(block.timestamp >= userStake.startTime + userStake.period, "Staking period not yet over");
        
        uint256 amountToReturn = userStake.amount;
        userStake.active = false;
        require(vegaVoteToken.transfer(msg.sender, amountToReturn), "Unstake failed");
        
        emit TokensUnstaked(msg.sender, amountToReturn);
    }

    function createVote(string memory description, uint256 duration, uint256 threshold) external onlyOwner {
        uint256 deadline = block.timestamp + duration;
        votes[nextVoteId] = Vote(description, deadline, threshold, 0, 0, false);
        emit VoteCreated(nextVoteId, description, deadline, threshold);
        nextVoteId++;
    }
    
    function vote(uint256 voteId, bool choice) external {
        require(block.timestamp < votes[voteId].deadline, "Vote ended");
        require(!hasVoted[msg.sender][voteId], "Already voted");
        
        uint256 totalVotingPower = 0;
        for (uint256 i = 0; i < stakes[msg.sender].length; i++) {
            if (stakes[msg.sender][i].active) {
                totalVotingPower = totalVotingPower + stakes[msg.sender][i].votingPower;
            }
        }
        require(totalVotingPower > 0, "No voting power");
        
        hasVoted[msg.sender][voteId] = true;
        
        if (choice) {
            votes[voteId].yesVotes = votes[voteId].yesVotes + totalVotingPower;
        } else {
            votes[voteId].noVotes = votes[voteId].noVotes + totalVotingPower;
        }
        
        if (votes[voteId].yesVotes + votes[voteId].noVotes >= votes[voteId].threshold) {
            finalizeVote(voteId);
        }
        
        emit Voted(msg.sender, voteId, choice, totalVotingPower);
    }
    
    function finalizeVote(uint256 voteId) public {
        require(block.timestamp >= votes[voteId].deadline || votes[voteId].yesVotes + votes[voteId].noVotes >= votes[voteId].threshold, "Can't end vote now");
        require(!votes[voteId].finalized, "Vote is already ended");
        
        votes[voteId].finalized = true;
        bool passed = votes[voteId].yesVotes > votes[voteId].noVotes;
        
        string memory metadataURI = generateMetadataURI(voteId, passed);
        _mintNFT(metadataURI);
        
        emit VoteFinalized(voteId, passed);
    }
    
    function generateMetadataURI(uint256 voteId, bool passed) internal view returns (string memory) {
        string memory result = passed ? "Yes" : "No";
        return string(abi.encodePacked(
            "data:application/json;utf8,",
            "{\"name\":\"Vega Vote Result #", voteId, "\",",
            "\"description\":\"", votes[voteId].description, "\",",
            "\"result\":\"", result, "\",",
            "\"yesVotes\":", votes[voteId].yesVotes, ",",
            "\"noVotes\":", votes[voteId].noVotes, ",",
            "\"threshold\":", votes[voteId].threshold, "}"
        ));
    }
    
    function _mintNFT(string memory metadataURI) internal {
        _safeMint(msg.sender, nextNftId);
        _setTokenURI(nextNftId, metadataURI);
        emit NFTMinted(nextNftId, metadataURI);
        nextNftId++;
    }
}
