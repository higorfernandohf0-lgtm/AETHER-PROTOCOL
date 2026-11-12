// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockAggregatorV3 {
    int256 private _answer;
    uint256 private _updatedAt;

    constructor(int256 initialAnswer, uint256 initialUpdatedAt) {
        _answer = initialAnswer;
        _updatedAt = initialUpdatedAt;
    }

    function setAnswer(int256 newAnswer, uint256 newUpdatedAt) external {
        _answer = newAnswer;
        _updatedAt = newUpdatedAt;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (1, _answer, _updatedAt, _updatedAt, 1);
    }
}