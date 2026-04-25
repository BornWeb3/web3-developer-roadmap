// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract CalldataPlayground {

    uint256 private number;

    event RawCalldata(bytes data);

    function setNumber(uint256 _value) external {
        number = _value;
    }

    function getNumber() external view returns (uint256) {
        return number;
    }

    fallback() external payable {
        emit RawCalldata(msg.data);
    }

    receive() external payable {}
}
