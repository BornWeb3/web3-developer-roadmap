// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract VulnerableVault {

    mapping(address => uint256) public balances;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function deposit() external payable {
        require(msg.value > 0, "ZERO_VALUE");
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "NO_BALANCE");

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH_SEND_FAILED");

        balances[msg.sender] = 0;

        emit Withdrawn(msg.sender, amount);
    }

    function vaultBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
