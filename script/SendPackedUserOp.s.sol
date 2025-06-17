// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "@aa/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "@aa/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Constants} from "script/HelperConfig.s.sol";

contract SendPackedUserOp is Script, Constants {
    using MessageHashUtils for bytes32;

    function run() external {
        //get the usdc address of the specified chain
        //get the minimal contract address over that chain.
        //get the pakedUser opeartion using generateSignedUserOperation()
        //call handle ops function of entryPoint contract address.
    }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory networkConfig,
        address minimalAccount
    ) external returns (PackedUserOperation memory) {
        address entryPoint = networkConfig.entryPoint;
        address sender = minimalAccount;
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        //IEntryPoint(entryPoint).getNonce(minimalAccount, 0);
        //generate the unsigned packed userOps
        PackedUserOperation memory userOp = _generateUnSignedUserOperation(callData, sender, nonce);
        //get the user operation hash
        bytes32 userOpHash = IEntryPoint(entryPoint).getUserOpHash(userOp);
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        //sign it
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == LOCAL_CHAINID) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(networkConfig.account, digest);
        }

        userOp.signature = abi.encodePacked(r, s, v);
        IEntryPoint(entryPoint).incrementNonce(0);
        return userOp;
    }

    function _generateUnSignedUserOperation(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
