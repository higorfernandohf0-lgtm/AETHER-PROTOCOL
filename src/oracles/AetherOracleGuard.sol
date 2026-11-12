// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAggregatorV3 {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract AetherOracleGuard {
    IAggregatorV3 public immutable priceFeed;
    uint256 public immutable stalenessThreshold;
    int256 public immutable minPrice;
    int256 public immutable maxPrice;

    error StalePrice(uint256 updatedAt);
    error PriceOutOfBounds(int256 price);
    error InvalidPrice();

    constructor(
        address _priceFeed,
        uint256 _stalenessThreshold,
        int256 _minPrice,
        int256 _maxPrice
    ) {
        require(_priceFeed != address(0), "Invalid price feed");
        require(_stalenessThreshold > 0, "Invalid threshold");
        require(_minPrice < _maxPrice, "Invalid bounds");

        priceFeed = IAggregatorV3(_priceFeed);
        stalenessThreshold = _stalenessThreshold;
        minPrice = _minPrice;
        maxPrice = _maxPrice;
    }

    /// @notice Retorna o preço atual validado
    function getValidatedPrice() external view returns (int256) {
        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();

        if (answer <= 0) {
            revert InvalidPrice();
        }

        if (block.timestamp - updatedAt > stalenessThreshold) {
            revert StalePrice(updatedAt);
        }

        if (answer < minPrice || answer > maxPrice) {
            revert PriceOutOfBounds(answer);
        }

        return answer;
    }
}