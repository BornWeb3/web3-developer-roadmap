// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract GasOptimized {
    uint256 public counter;
    uint256[] public numbers;
    mapping(address => uint256) public balances;

    function addNumber(uint256 num) external {
        numbers.push(num);
        uint256 currentBalance = balances[msg.sender];
        balances[msg.sender] = currentBalance + num;
    }

    function incrementMany(uint256 times) external {
        uint256 localCounter = counter;

        for (uint256 i = 0; i < times; ) {
            localCounter += 1;
            unchecked {
                i++;
            }
        }

        counter = localCounter;
    }

    function sumNumbers() external view returns (uint256 total) {
        uint256 length = numbers.length;
        for (uint256 i = 0; i < length; ) {
            total += numbers[i];
            unchecked {
                i++;
            }
        }
    }
}
