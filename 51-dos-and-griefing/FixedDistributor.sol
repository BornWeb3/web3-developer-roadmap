// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract FixedDistributor {
    address[] public users;
    mapping(address => uint256) public balances;

    uint256 public totalReceived;
    uint256 public totalWithdrawn;

    event Deposited(
        address indexed user,
        uint256 amount,
        uint256 balanceAfter,
        uint256 userCountAfter
    );

    event Withdrawn(address indexed user, uint256 amount);

    receive() external payable {
        _deposit();
    }

    function deposit() external payable {
        _deposit();
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "NO_BALANCE");

        balances[msg.sender] = 0;
        totalWithdrawn += amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH_SEND_FAILED");

        emit Withdrawn(msg.sender, amount);
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
            uint256 withdrawn
        )
    {
        return (
            users.length,
            address(this).balance,
            totalReceived,
            totalWithdrawn
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
