// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Callee {
    enum CallType {
        None,
        DirectExternal,
        RouterForwarded,
        RouterNoValue
    }

    address public lastSender;
    uint256 public lastValue;
    uint256 public lastNumber;
    CallType public lastCallType;

    event ContextCaptured(
        address indexed sender,
        uint256 value,
        uint256 number,
        address indexed self,
        CallType callType
    );

    function captureContext(uint256 number, CallType callType) external payable {
        lastSender = msg.sender;
        lastValue = msg.value;
        lastNumber = number;
        lastCallType = callType;

        emit ContextCaptured(msg.sender, msg.value, number, address(this), callType);
    }

    function getState() external view returns (address, uint256, uint256, uint8) {
        return (lastSender, lastValue, lastNumber, uint8(lastCallType));
    }
}
