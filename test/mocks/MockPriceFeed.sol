// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {AggregatorV2V3Interface} from "../../src/interfaces/AggregatorV2V3Interface.sol";

contract MockPriceFeed is AggregatorV2V3Interface {
    uint8 private _decimals;
    int256 private _latestAnswer;

    constructor(uint8 decimals_, int256 latestAnswer_) {
        _decimals = decimals_;
        _latestAnswer = latestAnswer_;
    }

    function setLatestAnswer(int256 latestAnswer_) external {
        _latestAnswer = latestAnswer_;
    }

    //
    // V2 Interface:
    //
    function latestAnswer() external view override returns (int256) {
        return _latestAnswer;
    }

    function latestTimestamp() external pure returns (uint256) {
        return 0;
    }

    function latestRound() external pure returns (uint256) {
        return 0;
    }

    function getAnswer(uint256) external view returns (int256) {
        return _latestAnswer;
    }

    function getTimestamp(uint256) external pure returns (uint256) {
        return 0;
    }

    //
    // V3 Interface:
    //
    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external pure returns (string memory) {
        return "Mock Price Feed";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, _latestAnswer, 0, 0, 0);
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, _latestAnswer, 0, 0, 0);
    }
}
