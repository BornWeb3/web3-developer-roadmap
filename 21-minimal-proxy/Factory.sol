// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./VaultLogic.sol";

contract Factory {
    address public immutable implementation;
    address[] public clones;

    event CloneCreated(address indexed owner, address indexed clone);

    constructor(address _implementation) {
        require(_implementation != address(0), "ZERO_IMPLEMENTATION");
        implementation = _implementation;
    }

    function createClone() external returns (address clone) {
        clone = _clone(implementation);
        VaultLogic(clone).initialize(msg.sender);
        clones.push(clone);
        emit CloneCreated(msg.sender, clone);
    }

    function getClones() external view returns (address[] memory) {
        return clones;
    }

    function _clone(address impl) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)

            mstore(
                ptr,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )

            mstore(add(ptr, 0x14), shl(0x60, impl))

            mstore(
                add(ptr, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )

            instance := create(0, ptr, 0x37)
        }

        require(instance != address(0), "ERC1167: CREATE FAILED");
    }
}
