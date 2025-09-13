// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IFeeManager {
    /// @notice Calculates the fixed fee for a given share supply and elapsed time.
    /// @dev May update internal state related to fee accrual or realization.
    /// @param shareSupply The total supply of shares.
    /// @param elapsedTime The elapsed time since the last fee realization.
    /// @return fee The calculated fixed fee.
    function calculateFixedFee(uint256 shareSupply, uint256 elapsedTime) external returns (uint256);

    /// @notice Calculates the performance fee based on the share supply, share price performance and elapsed time.
    /// @dev May update internal state related to fee accrual or realization.
    /// @param currentShareSupply The current total supply of shares.
    /// @param oldSharePrice The previous share price of reference.
    /// @param newSharePrice The new share price of reference.
    /// @param elapsedTime The elapsed time since the last fee realization.
    /// @return fee The calculated performance fee.
    function calculatePerformanceFee(
        uint256 currentShareSupply,
        uint256 oldSharePrice,
        uint256 newSharePrice,
        uint256 elapsedTime
    ) external returns (uint256);

    /// @notice Distributes the fees to relevant recipients.
    /// @param fixedFee The fixed fee amount to be distributed.
    /// @param perfFee The performance fee amount to be distributed.
    function distributeFees(uint256 fixedFee, uint256 perfFee) external;
}
