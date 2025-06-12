// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {EntryPoint} from "@aa/core/EntryPoint.sol";

contract Constants {
    uint256 constant ETH_SEPOLIA_CHAINID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAINID = 300;
    uint256 constant LOCAL_CHAINID = 31337;
    address constant BURNER_WALLET = 0x0f5eEcc25c3C1C1Ac35bFe83f0635391a7Bfe36A;
    // address constant FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
     address constant ANVIL_DEFAULT_WALLET =  0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
}

contract HelperConfig is Script, Constants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPoint;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        if (block.chainid == ETH_SEPOLIA_CHAINID) {
            networkConfigs[ETH_SEPOLIA_CHAINID] = _getEthSepoliaNetworkConfig();
        } else if (block.chainid == ZKSYNC_SEPOLIA_CHAINID) {
            networkConfigs[ZKSYNC_SEPOLIA_CHAINID] = _getZksyncSepoliaNewtorkConfig();
        }
    }

    function getConfig() external returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainid) public returns (NetworkConfig memory) {
        if (block.chainid == LOCAL_CHAINID) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainid].account != address(0)) {
            return networkConfigs[chainid];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function _getEthSepoliaNetworkConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, BURNER_WALLET);
    }

    function _getZksyncSepoliaNewtorkConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig(address(0), BURNER_WALLET);
    }

    function getOrCreateAnvilEthConfig() internal returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }
        //deploy mocks
        vm.startBroadcast(ANVIL_DEFAULT_WALLET);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();
        localNetworkConfig = NetworkConfig({entryPoint: address(entryPoint), account: ANVIL_DEFAULT_WALLET});
        return localNetworkConfig;
    }
}
