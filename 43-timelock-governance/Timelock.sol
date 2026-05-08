// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Timelock {
    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        uint256 executeAfter;
        bool executed;
    }

    address public admin;

    uint256 public constant DELAY = 2 days;
    uint256 public transactionCount;

    mapping(uint256 => Transaction) public transactions;

    event TransactionQueued(
        uint256 indexed transactionId,
        address indexed target,
        uint256 value,
        uint256 executeAfter
    );

    event TransactionExecuted(uint256 indexed transactionId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "ONLY_ADMIN");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function queueTransaction(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyAdmin returns (uint256 transactionId) {
        require(target != address(0), "ZERO_TARGET");

        transactionCount++;
        transactionId = transactionCount;

        transactions[transactionId] = Transaction({
            target: target,
            value: value,
            data: data,
            executeAfter: block.timestamp + DELAY,
            executed: false
        });

        emit TransactionQueued(
            transactionId,
            target,
            value,
            block.timestamp + DELAY
        );
    }

    function executeTransaction(uint256 transactionId)
        external
        payable
        onlyAdmin
    {
        Transaction storage transaction = transactions[transactionId];

        require(!transaction.executed, "ALREADY_EXECUTED");
        require(
            block.timestamp >= transaction.executeAfter,
            "TIMELOCK_ACTIVE"
        );

        transaction.executed = true;

        (bool success, ) = transaction.target.call{value: transaction.value}(
            transaction.data
        );

        require(success, "EXECUTION_FAILED");

        emit TransactionExecuted(transactionId);
    }

    receive() external payable {}
}
