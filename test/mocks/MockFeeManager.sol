// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {IFeeManager} from "../../src/interfaces/IFeeManager.sol";
import {IMachine} from "../../src/interfaces/IMachine.sol";

/// @dev MockFeeManager contract for testing use only
contract MockFeeManager is IFeeManager {
    uint256 private constant RATE_DIVISOR = 1e18;

    address public immutable dao;

    // fee rates per second
    uint256 public fixedFeeRate;
    uint256 public perfFeeRate;

    uint256 public distributionRate;

    constructor(address _dao, uint256 _fixedFeeRate, uint256 _perfFeeRate) {
        dao = _dao;
        fixedFeeRate = _fixedFeeRate;
        perfFeeRate = _perfFeeRate;
        distributionRate = 1e18;
    }

    function calculateFixedFee(uint256 shareSupply, uint256 elapsedTime) external view returns (uint256) {
        return shareSupply * elapsedTime * fixedFeeRate / RATE_DIVISOR;
    }

    function calculatePerformanceFee(
        uint256 currentShareSupply,
        uint256 oldSharePrice,
        uint256 newSharePrice,
        uint256 elapsedTime
    ) external view returns (uint256) {
        if (newSharePrice > oldSharePrice) {
            return (newSharePrice - oldSharePrice) * currentShareSupply * elapsedTime * perfFeeRate
                / (RATE_DIVISOR * newSharePrice);
        }
        return 0;
    }

    function distributeFees(uint256 fixedFee, uint256 perfFee) external {
        address shareToken = IMachine(msg.sender).shareToken();
        uint256 distributionAmount = distributionRate * (fixedFee + perfFee) / RATE_DIVISOR;
        IERC20(shareToken).transferFrom(msg.sender, dao, distributionAmount);
    }

    function setFixedFeeRate(uint256 _fixedFeeRate) external {
        fixedFeeRate = _fixedFeeRate;
    }

    function setPerfFeeRate(uint256 _perfFeeRate) external {
        perfFeeRate = _perfFeeRate;
    }

    function setDistributionRate(uint256 _distributionRate) external {
        distributionRate = _distributionRate;
    }
}
