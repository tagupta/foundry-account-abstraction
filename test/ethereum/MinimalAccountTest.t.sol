// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint} from "script/SendPackedUserOp.s.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_SUCCESS} from "@aa/core/Helpers.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    MinimalAccount minimalAccount;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;
    SendPackedUserOp sendPackedUserOp;
    ERC20Mock usdc;
    uint256 private constant USDC_INITIAL_VALUE = 1 ether;
    uint256 private constant MINIMAL_ACCOUNT_BALANCE = 1 ether;
    address private RAN_USER = makeAddr("random user");

    function setUp() external {
        DeployMinimal deployer = new DeployMinimal();
        (helperConfig, minimalAccount) = deployer.deployMinimalAccount();
        config = helperConfig.getConfig();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    //USDC mint
    //msg.sender => minimalAccount
    //action: mint some amount of usdc for minimalAccount
    //request is coming from the owner of minimalAccount directly
    function testOwnerCanExecuteCommands() external {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        bytes memory data = abi.encodeCall(ERC20Mock.mint, (address(minimalAccount), USDC_INITIAL_VALUE));
        //Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(address(usdc), 0, data);
        //Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), USDC_INITIAL_VALUE);
    }

    function testNonOwnerCanNotExecuteCommands() external {
        //Arrange
        bytes memory data = abi.encodeCall(ERC20Mock.mint, (address(minimalAccount), USDC_INITIAL_VALUE));
        //Act
        vm.prank(RAN_USER);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(address(usdc), 0, data);
    }

    function testRecoverSignedOp() external {
        //Arrange
        address dst = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeCall(ERC20Mock.mint, (address(minimalAccount), USDC_INITIAL_VALUE));
        bytes memory executeCalldata = abi.encodeCall(MinimalAccount.execute, (dst, value, functionData));

        PackedUserOperation memory packedUserOpeartion =
            sendPackedUserOp.generateSignedUserOperation(executeCalldata, config, address(minimalAccount));
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(packedUserOpeartion);
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);

        //Act
        address recoveredAddress = ECDSA.recover(digest, packedUserOpeartion.signature);
        //Assert
        assertEq(recoveredAddress, minimalAccount.owner());
    }

    //1. Sign user ops
    //2. CallValidate user ops
    //3. Assert that the return is correct.
    function testValidationOfUserOps() external {
        //Arrange
        address dst = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeCall(ERC20Mock.mint, (address(minimalAccount), USDC_INITIAL_VALUE));
        bytes memory executeCalldata = abi.encodeCall(MinimalAccount.execute, (dst, value, functionData));
        PackedUserOperation memory packedUserOperation =
            sendPackedUserOp.generateSignedUserOperation(executeCalldata, config, address(minimalAccount));
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(packedUserOperation);
        //Act
        uint256 missingAccountFunds = 1e18;
        vm.deal(address(minimalAccount), MINIMAL_ACCOUNT_BALANCE);
        vm.prank(config.entryPoint);
        uint256 success = minimalAccount.validateUserOp(packedUserOperation, userOpHash, missingAccountFunds);
        //Assert
        assertEq(success, SIG_VALIDATION_SUCCESS);
    }

    function testEntryPointCanExecuteCommand() external {
        //Arrange
        address dst = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeCall(ERC20Mock.mint, (address(minimalAccount), USDC_INITIAL_VALUE));
        bytes memory executeCalldata = abi.encodeCall(MinimalAccount.execute, (dst, value, functionData));
        PackedUserOperation memory packedUserOperation =
            sendPackedUserOp.generateSignedUserOperation(executeCalldata, config, address(minimalAccount));
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOperation;
        vm.deal(address(minimalAccount), MINIMAL_ACCOUNT_BALANCE);

        //Act
        vm.prank(RAN_USER);
        IEntryPoint(config.entryPoint).handleOps(ops, payable(RAN_USER));
        //assert
        assertEq(usdc.balanceOf(address(minimalAccount)), USDC_INITIAL_VALUE);
    }
}
