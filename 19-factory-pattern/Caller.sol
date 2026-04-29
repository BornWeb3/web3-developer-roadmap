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

contract Caller {
    function callDirect(address callee, uint256 number) external payable {
        ICallee(callee).captureContext{value: msg.value}(number, ICallee.CallType.DirectExternal);
    }

    function callViaRouter(address router, address callee, uint256 number) external payable {
        (bool success, ) = router.call{value: msg.value}(
            abi.encodeWithSignature(
                "forwardCall(address,uint256)",
                callee,
                number
            )
        );
        require(success, "Router call failed");
    }

    function callViaRouterNoValue(address router, address callee, uint256 number) external {
        (bool success, ) = router.call(
            abi.encodeWithSignature(
                "forwardCallNoValue(address,uint256)",
                callee,
                number
            )
        );
        require(success, "Router call failed");
    }
}
