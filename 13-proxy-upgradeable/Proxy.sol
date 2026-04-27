// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Proxy {

    bytes32 private constant IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("proxy.implementation")) - 1);

    bytes32 private constant ADMIN_SLOT =
        bytes32(uint256(keccak256("proxy.admin")) - 1);

    constructor(address initialImplementation) {
        require(initialImplementation != address(0), "impl=0");
        _setAdmin(msg.sender);
        _setImplementation(initialImplementation);
    }

    function implementation() public view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function admin() public view returns (address adm) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }

    function upgrade(address newImplementation) external {
        require(msg.sender == admin(), "only admin");
        require(newImplementation != address(0), "impl=0");
        _setImplementation(newImplementation);
    }

    fallback() external payable {
        _delegate(implementation());
    }

    receive() external payable {
        _delegate(implementation());
    }

    function _setImplementation(address newImplementation) private {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    function _setAdmin(address newAdmin) private {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }

    function _delegate(address target) private {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), target, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
