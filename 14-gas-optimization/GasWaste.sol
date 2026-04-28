// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract GasWaste {

    uint256 public counter;

    uint256[] public numbers;

    mapping(address => uint256) public balances;

    function addNumber(uint256 num) external {
        numbers.push(num);
        balances[msg.sender] += num;
    }

    function incrementMany(uint256 times) external {
        for (uint256 i = 0; i < times; i++) {
            counter += 1;
        }
    }

    function sumNumbers() external view returns (uint256 total) {
        for (uint256 i = 0; i < numbers.length; i++) {
            total += numbers[i];
        }
    }
}
