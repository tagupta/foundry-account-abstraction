// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {ERC20Mock} from '@openzeppelin/contracts/mocks/token/ERC20Mock.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MinimalAccountTest is Test {
    MinimalAccount minimalAccount;
    HelperConfig helperConfig;
    address entryPoint;
    address accountOwner;
    ERC20Mock usdc;
    uint256 private constant USDC_INITIAL_VALUE = 1 ether;
    address private RAN_USER = makeAddr("random user");

    function setUp() external {
        DeployMinimal deployer = new DeployMinimal();
        (helperConfig, minimalAccount) = deployer.deployMinimalAccount();
        entryPoint = helperConfig.getConfig().entryPoint;
        accountOwner = helperConfig.getConfig().account;
        usdc = new ERC20Mock();
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

    function testValidationOfUserOps() external {
        
    }
}
