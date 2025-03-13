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

    event VoteCreated(
        uint256 indexed voteId,
        string description,
        uint256 deadline,
        uint256 threshold
    );
    event Voted(
        address indexed voter,
        uint256 indexed voteId,
        bool choice,
        uint256 power
    );
    event VoteFinalized(uint256 indexed voteId, bool passed);
    event NFTMinted(uint256 indexed nftId, string metadataURI);
    event TokensUnstaked(address indexed user, uint256 amount);

    constructor(
        address vegaToken
    ) ERC721("VotingResult", "VGVT") Ownable(msg.sender) {
        vegaVoteToken = IERC20(vegaToken);
    }

    function vote(
        uint256 amount,
        uint256 period,
        uint256 voteId,
        bool choice
    ) external {
        require(
            period >= 0 && period <= 4 days * 365 + 1 days,
            "Invalid staking period"
        );
        require(
            vegaVoteToken.transferFrom(msg.sender, address(this), amount),
            "Stake failed"
        );
        require(block.timestamp < votes[voteId].deadline, "Vote ended");
        uint256 power = amount * period ** 2;

        require(power > 0, "No power");
        stakes[msg.sender].push(
            Stake(amount, period, power, block.timestamp, true)
        );
        if (choice) {
            votes[voteId].yesVotes += power;
        } else {
            votes[voteId].noVotes += power;
        }

        if (
            votes[voteId].yesVotes >= votes[voteId].threshold ||
            votes[voteId].noVotes >= votes[voteId].threshold
        ) {
            endVote(voteId);
        }

        emit Voted(msg.sender, voteId, choice, power);
    }

    function unstakeTokens(uint256 stakeIndex) external {
        require(
            stakeIndex < stakes[msg.sender].length && stakeIndex >= 0,
            "Invalid stake index"
        );
        Stake storage userStake = stakes[msg.sender][stakeIndex];
        require(userStake.active, "Stake already returned");
        require(
            block.timestamp >= userStake.startTime + userStake.period,
            "Staking period not yet over"
        );

        uint256 amountToReturn = userStake.amount;
        userStake.active = false;
        require(
            vegaVoteToken.transfer(msg.sender, amountToReturn),
            "Return failed"
        );

        emit TokensUnstaked(msg.sender, amountToReturn);
    }
    //it is admins responsibility to end vote after deadline -- we cant execute big loop on chain
    function TryToEndVoteByDeadline(uint256 voteId) external onlyOwner {
        endVote(voteId);
    }

    function createVote(
        string memory description,
        uint256 duration,
        uint256 threshold
    ) external onlyOwner {
        uint256 deadline = block.timestamp + duration;
        votes[nextVoteId] = Vote(description, deadline, threshold, 0, 0, false);
        emit VoteCreated(nextVoteId, description, deadline, threshold);
        nextVoteId++;
    }

    function endVote(uint256 voteId) public {
        require(
            block.timestamp >= votes[voteId].deadline ||
                votes[voteId].yesVotes >= votes[voteId].threshold ||
                votes[voteId].noVotes >= votes[voteId].threshold,
            "Can't end vote now"
        );
        require(!votes[voteId].finalized, "Vote is already ended");

        votes[voteId].finalized = true;

        bool passed = votes[voteId].yesVotes > votes[voteId].noVotes;
        string memory metadataURI = generateMetadataURI(voteId, passed);
        _mintNFT(metadataURI);

        emit VoteFinalized(voteId, passed);
    }

    function generateMetadataURI(
        uint256 voteId,
        bool passed
    ) internal view returns (string memory) {
        string memory result = passed ? "Yes" : "No";
        return
            string(
                abi.encodePacked(
                    "data:application/json;utf8,",
                    '{"name":"Vega Vote Result #',
                    voteId,
                    '",',
                    '"description":"',
                    votes[voteId].description,
                    '",',
                    '"result":"',
                    result,
                    '",',
                    '"yesVotes":',
                    votes[voteId].yesVotes,
                    ",",
                    '"noVotes":',
                    votes[voteId].noVotes,
                    ",",
                    '"threshold":',
                    votes[voteId].threshold,
                    "}"
                )
            );
    }

    function _mintNFT(string memory metadataURI) internal {
        _safeMint(msg.sender, nextNftId);
        _setTokenURI(nextNftId, metadataURI);
        emit NFTMinted(nextNftId, metadataURI);
        nextNftId++;
    }
}
