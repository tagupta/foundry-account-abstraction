// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;
import {IAccount} from "@systemContracts/contracts/interfaces/IAccount.sol";
import {Transaction} from '@systemContracts/contracts/libraries/MemoryTransactionHelper.sol';

/**
 * @title ZkMinimalAccount
 * @author Tanu Gupta
 * Lifecycle of a type 113(0x71) transaction in ZKSync Era:
 * msg.sender is always going to the bootloader system contract.
 * Phases: Validation and Execution
 * Phase 1: 
 * 1. The user sends the transaction to the "zksync api client" (sort of a light node).
 * 2. The client checks to see if the nonce is unique by querying the NonceHolder system contract.
 * 3. The Zksync API client calls validateTransaction, which must update the nonce.
 * 
 */
contract ZkMinimalAccount is IAccount {

    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
        returns (bytes4 magic){

        }

    function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable{

        }

    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.
    function executeTransactionFromOutside(Transaction memory _transaction) external payable{

    }

    function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable{

        }

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
        external
        payable{

        }

}