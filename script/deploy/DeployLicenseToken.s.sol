// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "forge-std/Script.sol";
import { LicenceToken } from  "../../src/LicenseToken.sol";

contract DeployLicenseToken is Script {
    function run() public {
        deploy();
    }

    function deploy() public returns (LicenseToken) {
        vm.startBroadcast();
        LicenceToken token = new LicenceToken();
        vm.stopBroadcast();

        console.log("Reward token contract deployed at: ", address(token));

        return token;
    }
}