// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;

contract storage {

    address public owner;

    uint256 public x;

    mapping(address => uint256) public userChanges;

    event Increment(address indexed user, uint256 by, uint256 newValue);

    event Decrement(address indexed user, uint256 by, uint256 newValue);

    event Reset(address indexed user, uint256 oldValue, uint256 newValue);

    event SetValue(address indexed user, uint256 oldValue, uint256 newValue);

    error NotOwner();

    error ZeroValue();

    error UnderflowGuard();

    modifier onlyOwner() {

        if (msg.sender != owner) {

            revert NotOwner();

        }

        _;

    }

    constructor() {

        owner = msg.sender;

    }

    function _trackUserChange() internal {

        userChanges[msg.sender] += 1;

    }

    function inc() external {

        x += 1;

        _trackUserChange();

        emit Increment(msg.sender, 1, x);

    }

    function incBy(uint256 by) external {

        if (by == 0) {

            revert ZeroValue();

        }

        x += by;

        _trackUserChange();

        emit Increment(msg.sender, by, x);

    }

    function dec() external {

        if (x == 0) {

            revert UnderflowGuard();

        }

        x -= 1;

        _trackUserChange();

        emit Decrement(msg.sender, 1, x);

    }

    function decBy(uint256 by) external {

        if (by == 0) {

            revert ZeroValue();

        }

        if (x < by) {

            revert UnderflowGuard();

        }

        x -= by;

        _trackUserChange();

        emit Decrement(msg.sender, by, x);

    }

    function setValue(uint256 newValue) external onlyOwner {

        uint256 oldValue = x;

        x = newValue;

        _trackUserChange();

        emit SetValue(msg.sender, oldValue, newValue);

    }

    function reset() external onlyOwner {

        uint256 oldValue = x;

        x = 0;

        _trackUserChange();

        emit Reset(msg.sender, oldValue, 0);

    }

    function getDouble() external view returns (uint256) {

        return x * 2;

    }

    function getSquare() external view returns (uint256) {

        return x * x;

    }

}
