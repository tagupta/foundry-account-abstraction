// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

//ZkSync era imports
import {IAccount, ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "@systemContracts/contracts/interfaces/IAccount.sol";
import {Transaction, MemoryTransactionHelper} from "@systemContracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from "@systemContracts/contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "@systemContracts/contracts/Constants.sol";
import {INonceHolder} from "@systemContracts/contracts/interfaces/INonceHolder.sol";
import {Utils} from "@systemContracts/contracts/libraries/Utils.sol";
//OZ Imports
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";
/**
 * @title ZkMinimalAccount
 * @author Tanu Gupta
 * Lifecycle of a type 113(0x71) transaction in ZKSync Era:
 * msg.sender is always going to the bootloader system contract.
 * Phases: Validation and Execution
 * Phase 1:
 * 1. The user sends the transaction to the "zksync api client" (sort of a light node).
 * 2. The client checks to see if the nonce is unique by querying the NonceHolder system contract.
 * 3. The Zksync API client calls validateTransaction, which MUST update the nonce.
 * 4. The Zksync API client checks the nonce is actually updated.
 * 5. The Zksync API client calls payForTransaction, or prepareForPaymaster and validateAndPayForPaymasterTransaction.
 * 6. The Zksync API client verfifies that the bootLoader gets paid.
 *
 * Phase 2:
 * 1. The ZKSync API client passes the validated transaction to the main node/sequencer.
 * 2. The main node calls executeTransaction.
 * 3. If a paymaster is ued, the postTransaction is called.
 */

contract ZkMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    error ZkMinimalAccount__NotEnoughBalance();
    error ZkMinimalAccount__NotFromBootLoader();
    error ZkMinimalAccount__ExecutionFailed();
    error ZkMinimalAccount__NotFromBootLoaderOrOwner();
    error ZkMinimalAccount__FailedToPay();
    error ZkMinimalAccount__InvalidSignature();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier requireFromBootLoader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAccount__NotFromBootLoader();
        }
        _;
    }

    modifier requireFromBootLoaderOrOwner() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert ZkMinimalAccount__NotFromBootLoaderOrOwner();
        }
        _;
    }

    constructor() Ownable(msg.sender) {}
    receive() external payable {}
    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Validates a transaction and must update the nonce.
     * @notice Checks the owner signed the transaction
     * @notice ckecks to see if we have enough money in this account to pay for the transaction.
     * @param _transaction The transaction details
     */

    function validateTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction)
        external
        payable
        requireFromBootLoader
        returns (bytes4 magic)
    {
        magic = _validateTransaction(_transaction);
        return magic;
    }

    function executeTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction)
        external
        payable
        requireFromBootLoaderOrOwner
    {
        _executeTransaction(_transaction);
    }

    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.
    function executeTransactionFromOutside(Transaction memory _transaction) external payable {
        bytes4 magic = _validateTransaction(_transaction);
        if( magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
            revert ZkMinimalAccount__InvalidSignature();
        }
        _executeTransaction(_transaction);
    }

    function payForTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction)
        external
        payable
    {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZkMinimalAccount__FailedToPay();
        }
    }

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
        external
        payable
    {}
    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _validateTransaction(Transaction memory _transaction) internal returns (bytes4 magic) {
        //Call nonceHolder contract to increment the nonce
        //System call simulation
        console.log("Making a system call to increment the nonce");
        SystemContractsCaller.systemCallWithPropagatedRevert(
            Utils.safeCastToU32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );
        //check for the fee to pay
        console.log("Checking if we have enough balance to pay for the transaction");
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        if (totalRequiredBalance > address(this).balance) {
            revert ZkMinimalAccount__NotEnoughBalance();
        }
        //Check the signature
        bytes32 txHash = _transaction.encodeHash();
        address signer = ECDSA.recover(txHash, _transaction.signature);
        bool isValidSigner = signer == owner();
        if (isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
        return magic;
    }

    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            if (!success) {
                revert ZkMinimalAccount__ExecutionFailed();
            }
        }
    }
}
