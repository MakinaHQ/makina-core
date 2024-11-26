// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

interface ICaliberInbox {
    error NotCaliber();

    struct AccountingMessageSlim {
        uint256 lastAccountingTime;
        uint256 totalAccountingTokenValue;
        bytes[] totalReceivedFromHM; // abi.encode(baseToken, nativeValue)
        bytes[] totalSentToHM; // abi.encode(baseToken, nativeValue)
    }

    struct AccountingMessageFull {
        uint256 lastAccountingTime;
        uint256 totalAccountingTokenValue;
        bytes[] totalReceivedFromHM; // abi.encode(baseToken, nativeValue)
        bytes[] totalSentToHM; // abi.encode(baseToken, nativeValue)
        bytes[] positions; // abi.encode(positionId, positionSize)
    }

    /// @notice Initializer of the contract
    function initialize(address _caliber, address _hubMachineInbox) external;

    /// @notice Address of the associated caliber
    function caliber() external view returns (address);

    /// @notice Address of the hub machine inbox
    function hubMachineInbox() external view returns (address);

    /// @notice Token => pending amount received from the hub machine, awaiting transfer to the caliber
    function pendingReceivedFromHubMachine(address token) external view returns (uint256);

    /// @notice Token => cumulative amount received from the hub machine
    function totalReceivedFromHubMachine(address token) external view returns (uint256);

    /// @notice Token => cumulative amount sent to the hub machine
    function totalSentToHubMachine(address token) external view returns (uint256);

    /// @notice Notifies the contract of a token amount received from the hub machine
    function notifyAmountFromHubMachine(address token, uint256 amount) external;

    /// @notice Transfers all pending received base tokens to the caliber
    /// @dev Only tokens registered as base tokens in the Caliber contract will be transferred
    function withdrawPendingReceivedAmounts() external;

    /// @notice Initializes a transfer of a given token amount to the hub machine
    /// @param token Token to transfer
    /// @param amount Token amount to transfer
    function initTransferToHubMachine(address token, uint256 amount) external;

    /// @notice Format accounting message based on caliber accounting data
    /// @param _totalAccountingTokenValue Total value (expressed in caliber's accounting token) held by the caliber
    /// @return accountingMessage The accounting message
    function relayAccounting(uint256 _totalAccountingTokenValue)
        external
        returns (AccountingMessageSlim memory accountingMessage);
}
