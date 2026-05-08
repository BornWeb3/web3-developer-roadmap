// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IOraclePair {
    function reserve0() external view returns (uint256);
    function reserve1() external view returns (uint256);
    function getSpotPrice(address baseToken) external view returns (uint256 priceE18);
}

contract AMMOracle {
    address public immutable owner;
    address public immutable pair;
    address public immutable baseToken;
    address public immutable quoteToken;

    uint256 public fallbackPriceE18;

    event FallbackPriceUpdated(uint256 oldPriceE18, uint256 newPriceE18);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(
        address _pair,
        address _baseToken,
        address _quoteToken,
        uint256 _initialFallbackPriceE18
    ) {
        owner = msg.sender;
        pair = _pair;
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        fallbackPriceE18 = _initialFallbackPriceE18;
    }

    function setFallbackPrice(uint256 newPriceE18) external onlyOwner {
        emit FallbackPriceUpdated(fallbackPriceE18, newPriceE18);
        fallbackPriceE18 = newPriceE18;
    }

    function getPrice() public view returns (uint256) {
        uint256 r0 = IOraclePair(pair).reserve0();
        uint256 r1 = IOraclePair(pair).reserve1();

        if (r0 == 0 || r1 == 0) {
            return fallbackPriceE18;
        }

        return IOraclePair(pair).getSpotPrice(baseToken);
    }

    function getSafePrice() external view returns (uint256 priceE18, bool usedFallback) {
        uint256 r0 = IOraclePair(pair).reserve0();
        uint256 r1 = IOraclePair(pair).reserve1();

        if (r0 == 0 || r1 == 0) {
            return (fallbackPriceE18, true);
        }

        return (OraclePair(pair).getSpotPrice(baseToken), false);
    }
}
