// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ICallee {
    enum CallType {
        None,
        DirectExternal,
        RouterForwarded,
        RouterNoValue
    }

    function captureContext(uint256 number, CallType callType) external payable;
}

contract Router {
    function forwardCall(address callee, uint256 number) external payable {
        ICallee(callee).captureContext{value: msg.value}(number, ICallee.CallType.RouterForwarded);
    }

    function forwardCallNoValue(address callee, uint256 number) external {
        ICallee(callee).captureContext(number, ICallee.CallType.RouterNoValue);
    }
}
