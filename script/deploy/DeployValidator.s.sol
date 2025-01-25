// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Validator} from  "../../src/Validator.sol";

contract DeployValidator is Script {
    function run() public {
        deploy();
    }

    function deploy() public returns (Validator) {
        vm.startBroadcast();
        Validator token = new Validator();
        vm.stopBroadcast();

        console.log("Validator contract deployed at: ", address(token));

        return token;
    }
}