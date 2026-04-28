// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Unchecked {

    uint256 public counter;

    function incrementChecked(uint256 times) external {
        for (uint256 i = 0; i < times; i++) {
            counter += 1;
        }
    }

    function incrementUnchecked(uint256 times) external {
        for (uint256 i = 0; i < times; i++) {
            unchecked {
                counter += 1;
            }
        }
    }
}
