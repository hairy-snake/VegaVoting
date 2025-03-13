// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/VegaVoting.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        address addr = vm.envAddress("TOKEN_CONTRACT");
        vm.startBroadcast();
        VegaVoting vegaVoting = new VegaVoting(addr);
        console.log("Deployed contract address:", address(vegaVoting));
        vm.stopBroadcast();
    }
}
