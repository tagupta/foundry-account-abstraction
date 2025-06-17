// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "src/zksync/ZKMinimalAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Transaction, MemoryTransactionHelper} from "@systemContracts/contracts/libraries/MemoryTransactionHelper.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "@systemContracts/contracts/Constants.sol";
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "@systemContracts/contracts/interfaces/IAccount.sol";


contract ZkMinimalAccountTest is Test {
    using MemoryTransactionHelper for Transaction;

    ZkMinimalAccount zkMinimalAccount;
    ERC20Mock usdc;
    uint256 private constant USDC_INITIAL_VALUE = 1 ether;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address private RANDOM_USER = makeAddr("random user");
    uint256 private constant INITIAL_MINIMAL_ACCOUNT_BALANCE = 1 ether;
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
        zkMinimalAccount = new ZkMinimalAccount();
        zkMinimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdc = new ERC20Mock();
        vm.deal(address(zkMinimalAccount), INITIAL_MINIMAL_ACCOUNT_BALANCE); // Ensure zkMinimalAccount has enough balance

    }

    function testZkOwnerCanExecuteCommands() external {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeCall(ERC20Mock.mint, (address(zkMinimalAccount), USDC_INITIAL_VALUE));
        Transaction memory transaction = _createTransaction(zkMinimalAccount.owner(), 113, dest, value, functionData);
        //Act
        vm.prank(zkMinimalAccount.owner());
        zkMinimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
        //Assert
        assertEq(usdc.balanceOf(address(zkMinimalAccount)), USDC_INITIAL_VALUE);
    }

    function testNonZKOwnerCanNotExecuteCommands() external {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeCall(ERC20Mock.mint, (address(zkMinimalAccount), USDC_INITIAL_VALUE));
        Transaction memory transaction = _createTransaction(address(this), 113, dest, value, functionData);
        //Act
        vm.prank(RANDOM_USER);
        vm.expectRevert(ZkMinimalAccount.ZkMinimalAccount__NotFromBootLoaderOrOwner.selector);
        zkMinimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
    }

    function testZKValidateTransaction() external {
        //Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeCall(ERC20Mock.mint, (address(zkMinimalAccount), USDC_INITIAL_VALUE));
        Transaction memory transaction = _createTransaction(address(this), 113, dest, value, functionData);
        transaction = _signTransaction(transaction);
        //Act

        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = zkMinimalAccount.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
        //Assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }
 
    /*/////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/
    function _signTransaction(Transaction memory transaction) internal view returns (Transaction memory) {
        bytes32 txHash = transaction.encodeHash();
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, txHash);
        transaction.signature = abi.encodePacked(r, s, v);
        return transaction;
    }

    function _createTransaction(address from, uint256 txType, address to, uint256 value, bytes memory data)
        internal
        view
        returns (Transaction memory)
    {
        uint256 nonce = vm.getNonce(address(zkMinimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);
        return Transaction({
            txType: txType, //113 (0x71)
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 16777216,
            gasPerPubdataByteLimit: 16777216,
            maxFeePerGas: 16777216,
            maxPriorityFeePerGas: 16777216,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: [uint256(0), 0, 0, 0],
            data: data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }
}
