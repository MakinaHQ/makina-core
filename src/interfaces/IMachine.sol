// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {GuardianSignature} from "@wormhole/sdk/libraries/VaaLib.sol";

import {IMachineEndpoint} from "./IMachineEndpoint.sol";

interface IMachine is IMachineEndpoint {
    event CaliberStaleThresholdChanged(uint256 indexed oldThreshold, uint256 indexed newThreshold);
    event Deposit(address indexed sender, address indexed receiver, uint256 assets, uint256 shares);
    event DepositorChanged(address indexed oldDepositor, address indexed newDepositor);
    event FeeManagerChanged(address indexed oldFeeManager, address indexed newFeeManager);
    event FeeMintCooldownChanged(uint256 indexed oldFeeMintCooldown, uint256 indexed newFeeMintCooldown);
    event FeesMinted(uint256 shares);
    event MaxFixedFeeAccrualRateChanged(uint256 indexed oldMaxAccrualRate, uint256 indexed newMaxAccrualRate);
    event MaxPerfFeeAccrualRateChanged(uint256 indexed oldMaxAccrualRate, uint256 indexed newMaxAccrualRate);
    event Redeem(address indexed owner, address indexed receiver, uint256 assets, uint256 shares);
    event RedeemerChanged(address indexed oldRedeemer, address indexed newRedeemer);
    event ShareLimitChanged(uint256 indexed oldShareLimit, uint256 indexed newShareLimit);
    event SpokeBridgeAdapterSet(uint256 indexed chainId, uint256 indexed bridgeId, address indexed adapter);
    event SpokeCaliberMailboxSet(uint256 indexed chainId, address indexed caliberMailbox);
    event TotalAumUpdated(uint256 totalAum);
    event TransferToCaliber(uint256 indexed chainId, address indexed token, uint256 amount);

    /// @notice Initialization parameters.
    /// @param initialDepositor The address of the initial depositor.
    /// @param initialRedeemer The address of the initial redeemer.
    /// @param initialFeeManager The address of the initial fee manager.
    /// @param initialCaliberStaleThreshold The caliber accounting staleness threshold in seconds.
    /// @param initialMaxFixedFeeAccrualRate The maximum fixed fee accrual rate per second, 1e18 = 100%.
    /// @param initialMaxPerfFeeAccrualRate The maximum performance fee accrual rate per second, 1e18 = 100%.
    /// @param initialFeeMintCooldown The minimum time to be elapsed between two fee minting events in seconds.
    /// @param initialShareLimit The share cap value.
    struct MachineInitParams {
        address initialDepositor;
        address initialRedeemer;
        address initialFeeManager;
        uint256 initialCaliberStaleThreshold;
        uint256 initialMaxFixedFeeAccrualRate;
        uint256 initialMaxPerfFeeAccrualRate;
        uint256 initialFeeMintCooldown;
        uint256 initialShareLimit;
    }

    /// @dev Internal state structure for a spoke caliber data.
    /// @param mailbox The foreign address of the spoke caliber mailbox.
    /// @param bridgeAdapters The mapping of bridge IDs to their corresponding adapters.
    /// @param timestamp The timestamp of the last accounting.
    /// @param netAum The net AUM of the spoke caliber.
    /// @param positions The list of positions of the spoke caliber, each encoded as abi.encode(positionId, value).
    /// @param baseTokens The list of base tokens of the spoke caliber, each encoded as abi.encode(token, value).
    /// @param caliberBridgesIn The mapping of spoke caliber incoming bridge amounts.
    /// @param caliberBridgesOut The mapping of spoke caliber outgoing bridge amounts.
    /// @param machineBridgesIn The mapping of machine incoming bridge amounts.
    /// @param machineBridgesOut The mapping of machine outgoing bridge amounts.
    struct SpokeCaliberData {
        address mailbox;
        mapping(uint16 bridgeId => address adapter) bridgeAdapters;
        uint256 timestamp;
        uint256 netAum;
        bytes[] positions;
        bytes[] baseTokens;
        EnumerableMap.AddressToUintMap caliberBridgesIn;
        EnumerableMap.AddressToUintMap caliberBridgesOut;
        EnumerableMap.AddressToUintMap machineBridgesIn;
        EnumerableMap.AddressToUintMap machineBridgesOut;
    }

    /// @notice Initializer of the contract.
    /// @param mParams The machine initialization parameters.
    /// @param mgParams The makina governable initialization parameters.
    /// @param _preDepositVault The address of the pre-deposit vault.
    /// @param _shareToken The address of the share token.
    /// @param _accountingToken The address of the accounting token.
    /// @param _hubCaliber The address of the hub caliber.
    function initialize(
        MachineInitParams calldata mParams,
        MakinaGovernableInitParams calldata mgParams,
        address _preDepositVault,
        address _shareToken,
        address _accountingToken,
        address _hubCaliber
    ) external;

    /// @notice Address of the Wormhole Core Bridge.
    function wormhole() external view returns (address);

    /// @notice Address of the depositor.
    function depositor() external view returns (address);

    /// @notice Address of the redeemer.
    function redeemer() external view returns (address);

    /// @notice Address of the share token.
    function shareToken() external view returns (address);

    /// @notice Address of the accounting token.
    function accountingToken() external view returns (address);

    /// @notice Address of the hub caliber.
    function hubCaliber() external view returns (address);

    /// @notice Address of the fee manager.
    function feeManager() external view returns (address);

    /// @notice Maximum duration a caliber can remain unaccounted for before it is considered stale.
    function caliberStaleThreshold() external view returns (uint256);

    /// @notice Maximum fixed fee accrual rate per second used to compute an upper bound on shares to be minted, 1e18 = 100%.
    function maxFixedFeeAccrualRate() external view returns (uint256);

    /// @notice Maximum performance fee accrual rate per second used to compute an upper bound on shares to be minted, 1e18 = 100%.
    function maxPerfFeeAccrualRate() external view returns (uint256);

    /// @notice Minimum time to be elapsed between two fee minting events.
    function feeMintCooldown() external view returns (uint256);

    /// @notice Share token supply limit that cannot be exceeded by new deposits.
    function shareLimit() external view returns (uint256);

    /// @notice Maximum amount of shares that can currently be minted through asset deposits.
    function maxMint() external view returns (uint256);

    /// @notice Maximum amount of accounting tokens that can currently be withdrawn through share redemptions.
    function maxWithdraw() external view returns (uint256);

    /// @notice Last total machine AUM.
    function lastTotalAum() external view returns (uint256);

    /// @notice Timestamp of the last global machine accounting.
    function lastGlobalAccountingTime() external view returns (uint256);

    /// @notice Token => Is the token an idle token.
    function isIdleToken(address token) external view returns (bool);

    /// @notice Number of calibers associated with the machine.
    function getSpokeCalibersLength() external view returns (uint256);

    /// @notice Spoke caliber index => Spoke Chain ID.
    function getSpokeChainId(uint256 idx) external view returns (uint256);

    /// @notice Spoke Chain ID => Spoke caliber's AUM, individual positions values and accounting timestamp.
    function getSpokeCaliberDetailedAum(uint256 chainId)
        external
        view
        returns (uint256 aum, bytes[] memory positions, bytes[] memory baseTokens, uint256 timestamp);

    /// @notice Spoke Chain ID => Spoke Caliber Mailbox Address.
    function getSpokeCaliberMailbox(uint256 chainId) external view returns (address);

    /// @notice Spoke Chain ID => Spoke Bridge ID => Spoke Bridge Adapter.
    function getSpokeBridgeAdapter(uint256 chainId, uint16 bridgeId) external view returns (address);

    /// @notice Returns the amount of shares that the Machine would exchange for the amount of accounting tokens provided.
    /// @param assets The amount of accounting tokens.
    /// @return shares The amount of shares.
    function convertToShares(uint256 assets) external view returns (uint256);

    /// @notice Returns the amount of accounting tokens that the Machine would exchange for the amount of shares provided.
    /// @param shares The amount of shares.
    /// @return assets The amount of accounting tokens.
    function convertToAssets(uint256 shares) external view returns (uint256);

    /// @notice Initiates a token transfers to the hub caliber.
    /// @param token The address of the token to transfer.
    /// @param amount The amount of token to transfer.
    function transferToHubCaliber(address token, uint256 amount) external;

    /// @notice Initiates a token transfers to the spoke caliber.
    /// @param bridgeId The ID of the bridge to use for the transfer.
    /// @param chainId The foreign EVM chain ID of the spoke caliber.
    /// @param token The address of the token to transfer.
    /// @param amount The amount of token to transfer.
    /// @param minOutputAmount The minimum output amount expected from the transfer.
    function transferToSpokeCaliber(
        uint16 bridgeId,
        uint256 chainId,
        address token,
        uint256 amount,
        uint256 minOutputAmount
    ) external;

    /// @notice Updates the total AUM of the machine.
    /// @return totalAum The updated total AUM.
    function updateTotalAum() external returns (uint256);

    /// @notice Deposits accounting tokens into the machine and mints shares to the receiver.
    /// @param assets The amount of accounting tokens to deposit.
    /// @param receiver The receiver of minted shares.
    /// @param minShares The minimum amount of shares to be minted.
    /// @return shares The amount of shares minted.
    function deposit(uint256 assets, address receiver, uint256 minShares) external returns (uint256);

    /// @notice Redeems shares from the machine and transfers accounting tokens to the receiver.
    /// @param shares The amount of shares to redeem.
    /// @param receiver The receiver of the accounting tokens.
    /// @param minAssets The minimum amount of accounting tokens to be transferred.
    /// @return assets The amount of accounting tokens transferred.
    function redeem(uint256 shares, address receiver, uint256 minAssets) external returns (uint256);

    /// @notice Updates spoke caliber accounting data using Wormhole Cross-Chain Queries (CCQ).
    /// @dev Validates the Wormhole CCQ response and guardian signatures before updating state.
    /// @param response The Wormhole CCQ response payload containing the accounting data.
    /// @param signatures The array of Wormhole guardians signatures attesting to the validity of the response.
    function updateSpokeCaliberAccountingData(bytes memory response, GuardianSignature[] memory signatures) external;

    /// @notice Registers a spoke caliber mailbox and related bridge adapters.
    /// @param chainId The foreign EVM chain ID of the spoke caliber.
    /// @param spokeCaliberMailbox The address of the spoke caliber mailbox.
    /// @param bridges The list of bridges supported with the spoke caliber.
    /// @param adapters The list of corresponding adapters for each bridge. Must be the same length as `bridges`.
    function setSpokeCaliber(
        uint256 chainId,
        address spokeCaliberMailbox,
        uint16[] calldata bridges,
        address[] calldata adapters
    ) external;

    /// @notice Registers a spoke bridge adapter.
    /// @param chainId The foreign EVM chain ID of the adapter.
    /// @param bridgeId The ID of the bridge.
    /// @param adapter The foreign address of the bridge adapter.
    function setSpokeBridgeAdapter(uint256 chainId, uint16 bridgeId, address adapter) external;

    /// @notice Sets the depositor address.
    /// @param newDepositor The address of the new depositor.
    function setDepositor(address newDepositor) external;

    /// @notice Sets the redeemer address.
    /// @param newRedeemer The address of the new redeemer.
    function setRedeemer(address newRedeemer) external;

    /// @notice Sets the fee manager address.
    /// @param newFeeManager The address of the new fee manager.
    function setFeeManager(address newFeeManager) external;

    /// @notice Sets the caliber accounting staleness threshold.
    /// @param newCaliberStaleThreshold The new threshold in seconds.
    function setCaliberStaleThreshold(uint256 newCaliberStaleThreshold) external;

    /// @notice Sets the maximum fixed fee accrual rate.
    /// @param newMaxAccrualRate The new maximum fixed fee accrual rate per second, 1e18 = 100%.
    function setMaxFixedFeeAccrualRate(uint256 newMaxAccrualRate) external;

    /// @notice Sets the maximum performance fee accrual rate.
    /// @param newMaxAccrualRate The new maximum performance fee accrual rate per second, 1e18 = 100%.
    function setMaxPerfFeeAccrualRate(uint256 newMaxAccrualRate) external;

    /// @notice Sets the minimum time to be elapsed between two fee minting events.
    /// @param newFeeMintCooldown The new cooldown in seconds.
    function setFeeMintCooldown(uint256 newFeeMintCooldown) external;

    /// @notice Sets the new share token supply limit that cannot be exceeded by new deposits.
    /// @param newShareLimit The new share limit
    function setShareLimit(uint256 newShareLimit) external;
}
