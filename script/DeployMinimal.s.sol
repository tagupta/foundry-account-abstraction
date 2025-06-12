// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployMinimal is Script {
    function run() external returns (HelperConfig, MinimalAccount) {
        return deployMinimalAccount();
    }

    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        vm.startBroadcast(networkConfig.account);
        MinimalAccount minimalAccount = new MinimalAccount(networkConfig.entryPoint);
        minimalAccount.transferOwnership(networkConfig.account);
        vm.stopBroadcast();
        return (helperConfig, minimalAccount);
    }
}
