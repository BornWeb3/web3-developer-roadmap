// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract StoragePacking {

    uint128 public a;
    uint128 public b;
    uint256 public c;

    struct Packed {
        uint128 x;
        uint128 y;
    }

    struct NotPacked {
        uint128 x;
        uint256 y;
    }

    Packed public packedData;
    NotPacked public notPackedData;

    function setPacked(uint128 _x, uint128 _y) external {
        packedData = Packed(_x, _y);
    }

    function setNotPacked(uint128 _x, uint256 _y) external {
        notPackedData = NotPacked(_x, _y);
    }
}
