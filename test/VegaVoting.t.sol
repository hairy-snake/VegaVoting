// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/VegaVoting.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("TestToken", "TVG") {
        _mint(msg.sender, 10000000 ether);
    }
}

contract VegaVotingTest is Test {
    VegaVoting public vegaVoting;
    ERC20 public vegaToken;
    address public owner;
    address public user;
    address public anotherUser;

    function setUp() public {
        owner = address(this);
        user = address(0x1);
        anotherUser = address(0x2);

        vegaToken = new MockERC20();
        vegaVoting = new VegaVoting(address(vegaToken));
        vm.prank(owner);
        vegaToken.transfer(user, 1000 ether);
        vegaToken.transfer(anotherUser, 1000 ether);

        vm.prank(user);
        vegaToken.approve(address(vegaVoting), 1000 ether);

        vm.prank(anotherUser);
        vegaToken.approve(address(vegaVoting), 1000 ether);
    }

    function testStakeTokens() public {
        uint256 amount = 100 ether;
        uint256 period = 30 days;
        vm.prank(owner);
        vegaVoting.createVote("aboba", 100 days, 10 ** 10);
        vm.prank(user);
        vegaVoting.vote(amount, period, 0, true);

        (uint256 stakedAmount, , , , bool active) = vegaVoting.stakes(user, 0);

        assertEq(stakedAmount, amount);
        assertTrue(active);
    }

    function testUnstakeTokens() public {
        uint256 amount = 100 ether;
        uint256 period = 30 days;
        vm.prank(owner);
        string memory description = "Aboba?";
        vegaVoting.createVote(description, 100 days, 10 ** 10);
        vm.prank(user);
        vegaVoting.vote(amount, period, 0, true);

        vm.warp(block.timestamp + period);

        vm.prank(user);
        vegaVoting.unstakeTokens(0);

        (, , , , bool active) = vegaVoting.stakes(user, 0);
        assertFalse(active);
    }

    function testCreateVote() public {
        string memory description = "Aboba?";
        uint256 duration = 7 days;
        uint256 threshold = 100;

        vm.prank(owner);
        vegaVoting.createVote(description, duration, threshold);

        (
            string memory desc,
            uint256 deadline,
            uint256 thr,
            ,
            ,
            bool finalized
        ) = vegaVoting.votes(0);

        assertEq(desc, description);
        assertEq(deadline, block.timestamp + duration);
        assertEq(thr, threshold);
        assertFalse(finalized);
    }

    function testVote() public {
        string memory description = "Aboba?";
        uint256 duration = 7 days;
        uint256 threshold = 100;

        vm.prank(owner);
        vegaVoting.createVote(description, duration, threshold);

        uint256 amount = 100 ether;
        uint256 period = 30 days;

        vm.prank(user);
        vegaVoting.vote(amount, period, 0, true);

        (, , , uint256 yesVotes, uint256 noVotes, ) = vegaVoting.votes(0);

        assertEq(yesVotes, amount * period ** 2);
        assertEq(noVotes, 0);
    }

    function testVoteFailsIfNoPower() public {
        string memory description = "Aboba?";
        uint256 duration = 7 days;
        uint256 threshold = 100;

        vm.prank(owner);
        vegaVoting.createVote(description, duration, threshold);

        vm.prank(user);
        vm.expectRevert("No power");
        vegaVoting.vote(0, 1 days, 0, true);
    }

    function testFinalizeVote() public {
        string memory description = "Aboba?";
        uint256 duration = 7 days;
        uint256 threshold = 100;

        vm.prank(owner);
        vegaVoting.createVote(description, duration, threshold);

        uint256 amount = 100 ether;
        uint256 period = 30 days;

        vm.prank(user);
        vegaVoting.vote(amount, period, 0, true);

        (, , , uint256 yesVotes, uint256 noVotes, bool finalized) = vegaVoting
            .votes(0);

        assertTrue(finalized);
        assertEq(yesVotes, amount * period ** 2);
        assertEq(noVotes, 0);
    }
}
