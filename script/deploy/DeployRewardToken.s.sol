// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {RewardToken} from  "../../src/RewardToken.sol";

contract DeployRewardToken is Script {
    function run() public {
        deploy();
    }

    function deploy() public returns (RewardToken) {
        vm.startBroadcast();
        RewardToken token = new RewardToken(msg.sender);
        vm.stopBroadcast();

        console.log("License token contract deployed at: ", address(token));

        return token;
    }
}