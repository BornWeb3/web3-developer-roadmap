// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract ImplementationV1 {
    address public lastCaller;
    uint256 public number;

    function setNumber(uint256 _num) external {
        number = _num;
        lastCaller = msg.sender;
    }

    function getState() external view returns (address, uint256) {
        return (lastCaller, number);
    }
}
