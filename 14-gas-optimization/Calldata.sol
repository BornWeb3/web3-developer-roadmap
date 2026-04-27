// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Calldata {

    function sum(uint256[] calldata data) external pure returns (uint256 s) {
        uint256 len = data.length;
        for (uint256 i = 0; i < len; i++) {
            s += data[i];
        }
    }

    function getSelector() external pure returns (bytes4) {
        return this.sum.selector;
    }

    function encodeCall(uint256[] calldata data) external pure returns (bytes memory) {
        return abi.encodeWithSelector(this.sum.selector, data);
    }
}
