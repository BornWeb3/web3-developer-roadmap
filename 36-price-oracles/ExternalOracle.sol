// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract ExternalOracle {
    address public owner;
    uint256 private price;

    event PriceUpdated(uint256 newPrice);

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor(uint256 _initialPrice) {
        owner = msg.sender;
        price = _initialPrice;
    }

    function setPrice(uint256 _price) external onlyOwner {
        require(_price > 0, "INVALID_PRICE");
        price = _price;

        emit PriceUpdated(_price);
    }

    function getPrice() external view returns (uint256) {
        return price;
    }
}
