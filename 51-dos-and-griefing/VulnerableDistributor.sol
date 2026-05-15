// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract VulnerableDistributor {
    address[] public users;
    mapping(address => uint256) public balances;

    uint256 public totalReceived;
    uint256 public totalDistributed;

    event Deposited(
        address indexed user,
        uint256 amount,
        uint256 balanceAfter,
        uint256 userCountAfter
    );

    event DistributionStarted(
        uint256 userCount,
        uint256 contractBalance
    );

    event PaymentSent(
        address indexed user,
        uint256 amount
    );

    event DistributionCompleted(
        uint256 userCount,
        uint256 totalDistributedAfter
    );

    receive() external payable {
        _deposit();
    }

    function deposit() external payable {
        _deposit();
    }

    function distribute() external {
        uint256 count = users.length;

        require(count > 0, "NO_USERS");

        emit DistributionStarted(
            count,
            address(this).balance
        );

        for (uint256 i = 0; i < count; i++) {
            address user = users[i];
            uint256 amount = balances[user];

            if (amount == 0) {
                continue;
            }

            balances[user] = 0;
            totalDistributed += amount;

            (bool success, ) = payable(user).call{value: amount}("");

            require(success, "ETH_SEND_FAILED");

            emit PaymentSent(user, amount);
        }

        emit DistributionCompleted(
            count,
            totalDistributed
        );
    }

    function userCount() external view returns (uint256) {
        return users.length;
    }

    function status()
        external
        view
        returns (
            uint256 userCount_,
            uint256 contractBalance,
            uint256 received,
            uint256 distributed
        )
    {
        return (
            users.length,
            address(this).balance,
            totalReceived,
            totalDistributed
        );
    }

    function _deposit() internal {
        require(msg.value > 0, "ZERO_VALUE");

        users.push(msg.sender);

        balances[msg.sender] += msg.value;
        totalReceived += msg.value;

        emit Deposited(
            msg.sender,
            msg.value,
            balances[msg.sender],
            users.length
        );
    }
}
