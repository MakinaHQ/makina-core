// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IBridgeAdapter} from "./IBridgeAdapter.sol";
import {ICaliberMailbox} from "./ICaliberMailbox.sol";
import {IMachineEndpoint} from "./IMachineEndpoint.sol";

interface IMachine is IMachineEndpoint {
    error CaliberAccountingStale(uint256 caliberChainId);
    error InvalidChainId();
    error InvalidDecimals();
    error ExceededMaxMint(uint256 shares, uint256 max);
    error ExceededMaxWithdraw(uint256 assets, uint256 max);
    error MachineMailboxDoesNotExist();
    error MismatchedLength();
    error NotMailbox();
    error RecoveryMode();
    error SpokeBridgeAdapterAlreadySet();
    error SpokeBridgeAdapterNotSet();
    error SpokeCaliberAlreadySet();
    error UnauthorizedSender();
    error UnauthorizedDepositor();
    error UnauthorizedRedeemer();
    error UnauthorizedOperator();
    error ZeroBridgeAdapterAddress();

    event CaliberStaleThresholdChanged(uint256 indexed oldThreshold, uint256 indexed newThreshold);
    event Deposit(address indexed sender, address indexed receiver, uint256 assets, uint256 shares);
    event DepositorChanged(address indexed oldDepositor, address indexed newDepositor);
    event RedeemerChanged(address indexed oldRedeemer, address indexed newRedeemer);
    event HubCaliberDeployed(address indexed caliber);
    event ShareLimitChanged(uint256 indexed oldShareLimit, uint256 indexed newShareLimit);
    event MechanicChanged(address indexed oldMechanic, address indexed newMechanic);
    event RecoveryModeChanged(bool indexed enabled);
    event Redeem(address indexed owner, address indexed receiver, uint256 assets, uint256 shares);
    event SecurityCouncilChanged(address indexed oldSecurityCouncil, address indexed newSecurityCouncil);
    event SpokeBridgeAdapterSet(uint256 indexed chainId, uint256 indexed bridgeId, address indexed adapter);
    event SpokeCaliberMailboxSet(uint256 indexed chainId, address indexed caliberMailbox);
    event TotalAumUpdated(uint256 totalAum, uint256 timestamp);
    event TransferToCaliber(uint256 indexed chainId, address indexed token, uint256 amount);

    /// @notice Initialization parameters.
    /// @param accountingToken The address of the accounting token.
    /// @param initialMechanic The address of the initial mechanic.
    /// @param initialSecurityCouncil The address of the initial security council.
    /// @param initialAuthority The address of the initial authority.
    /// @param initialDepositor The address of the initial depositor.
    /// @param initialRedeemer The address of the initial redeemer.
    /// @param initialCaliberStaleThreshold The caliber accounting staleness threshold in seconds.
    /// @param initialShareLimit The share cap value.
    /// @param hubCaliberPosStaleThreshold The hub caliber's position accounting staleness threshold.
    /// @param hubCaliberAllowedInstrRoot The root of the Merkle tree containing allowed caliber instructions.
    /// @param hubCaliberTimelockDuration The duration of the hub caliber's Merkle tree root update timelock.
    /// @param hubCaliberMaxPositionIncreaseLossBps The max allowed value loss (in basis point) in the hub caliber when increasing a position.
    /// @param hubCaliberMaxPositionDecreaseLossBps The max allowed value loss (in basis point) in the hub caliber when decreasing a position.
    /// @param hubCaliberMaxSwapLossBps The max allowed value loss (in basis point) when swapping a base token into another in the hub caliber.
    /// @param hubCaliberInitialFlashLoanModule The address of the initial flashLoan module.
    struct MachineInitParams {
        address accountingToken;
        address initialMechanic;
        address initialSecurityCouncil;
        address initialAuthority;
        address initialDepositor;
        address initialRedeemer;
        uint256 initialCaliberStaleThreshold;
        uint256 initialShareLimit;
        uint256 hubCaliberPosStaleThreshold;
        bytes32 hubCaliberAllowedInstrRoot;
        uint256 hubCaliberTimelockDuration;
        uint256 hubCaliberMaxPositionIncreaseLossBps;
        uint256 hubCaliberMaxPositionDecreaseLossBps;
        uint256 hubCaliberMaxSwapLossBps;
        address hubCaliberInitialFlashLoanModule;
    }

    struct SpokeCaliberData {
        address mailbox;
        mapping(IBridgeAdapter.Bridge bridgeId => address adapter) bridgeAdapters;
        uint256 timestamp;
        uint256 netAum;
        bytes[] positions; // abi.encode(positionId, value)
        bytes[] baseTokens; // abi.encode(token, value)
        bytes[] caliberBridgesIn; // abi.encode(token, amount)
        bytes[] caliberBridgesOut; // abi.encode(token, amount)
        EnumerableMap.AddressToUintMap machineBridgesIn;
        EnumerableMap.AddressToUintMap machineBridgesOut;
    }

    /// @notice Initializer of the contract.
    /// @param params The initialization parameters.
    /// @param _shareToken The address of the share token.
    /// @param _hubCaliber The address of the hub caliber.
    function initialize(MachineInitParams calldata params, address _shareToken, address _hubCaliber) external;

    /// @notice Address of the Wormhole Core Bridge.
    function wormhole() external view returns (address);

    /// @notice Address of the mechanic.
    function mechanic() external view returns (address);

    /// @notice Address of the security council.
    function securityCouncil() external view returns (address);

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

    /// @notice Maximum duration a caliber can remain unaccounted for before it is considered stale.
    function caliberStaleThreshold() external view returns (uint256);

    /// @notice Share token supply limit that cannot be exceeded by new deposits.
    function shareLimit() external view returns (uint256);

    /// @notice Maximum amount of shares that can currently be minted through asset deposits.
    function maxMint() external view returns (uint256);

    /// @notice Maximum amount of assets that can currently be withdrawn through share redemptions.
    function maxWithdraw() external view returns (uint256);

    /// @notice Whether the machine is in recovery mode.
    function recoveryMode() external view returns (bool);

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

    /// @notice Spoke Chain ID => Spoke Caliber Accounting Data + Timestamp.
    function getSpokeCaliberAccountingData(uint256 chainId)
        external
        view
        returns (ICaliberMailbox.SpokeCaliberAccountingData memory, uint256 timestamp);

    /// @notice Spoke Chain ID => Spoke Caliber Mailbox Address.
    function getSpokeCaliberMailbox(uint256 chainId) external view returns (address);

    /// @notice Spoke Chain ID => Spoke Bridge ID => Spoke Bridge Adapter.
    function getSpokeBridgeAdapter(uint256 chainId, IBridgeAdapter.Bridge bridgeId) external view returns (address);

    /// @notice Returns the amount of shares that the Machine would exchange for the amount of assets provided.
    /// @param assets The amount of assets.
    /// @return shares The amount of shares.
    function convertToShares(uint256 assets) external view returns (uint256);

    /// @notice Returns the amount of assets that the Machine would exchange for the amount of shares provided.
    /// @param shares The amount of shares.
    /// @return assets The amount of assets.
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
        IBridgeAdapter.Bridge bridgeId,
        uint256 chainId,
        address token,
        uint256 amount,
        uint256 minOutputAmount
    ) external;

    /// @notice Updates the total AUM of the machine.
    /// @return totalAum The updated total AUM.
    function updateTotalAum() external returns (uint256);

    /// @notice Deposits accounting tokens into the machine and mints shares to the receiver
    /// @param assets The amount of accounting tokens to deposit
    /// @param receiver The receiver of minted shares
    /// @return shares The amount of shares minted
    function deposit(uint256 assets, address receiver) external returns (uint256);

    /// @notice Registers a spoke caliber mailbox and related bridge adapters.
    /// @param chainId The foreign EVM chain ID of the spoke caliber.
    /// @param spokeCaliberMailbox The address of the spoke caliber mailbox.
    /// @param bridges The list of bridges supported with the spoke caliber.
    /// @param adapters The list of corresponding adapters for each bridge. Must be the same length as `bridges`.
    function setSpokeCaliber(
        uint256 chainId,
        address spokeCaliberMailbox,
        IBridgeAdapter.Bridge[] calldata bridges,
        address[] calldata adapters
    ) external;

    /// @notice Registers a spoke bridge adapter.
    /// @param chainId The foreign EVM chain ID of the adapter.
    /// @param bridgeId The ID of the bridge.
    /// @param adapter The foreign address of the bridge adapter.
    function setSpokeBridgeAdapter(uint256 chainId, IBridgeAdapter.Bridge bridgeId, address adapter) external;

    /// @notice Sets a new mechanic.
    /// @param newMechanic The address of new mechanic.
    function setMechanic(address newMechanic) external;

    /// @notice Sets a new security council.
    /// @param newSecurityCouncil The address of the new security council.
    function setSecurityCouncil(address newSecurityCouncil) external;

    /// @notice Sets the depositor address.
    /// @param newDepositor The address of the new depositor.
    function setDepositor(address newDepositor) external;

    /// @notice Sets the redeemer address.
    /// @param newRedeemer The address of the new redeemer.
    function setRedeemer(address newRedeemer) external;

    /// @notice Sets the caliber accounting staleness threshold.
    /// @param newCaliberStaleThreshold The new threshold in seconds.
    function setCaliberStaleThreshold(uint256 newCaliberStaleThreshold) external;

    /// @notice Sets the new share token supply limit that cannot be exceeded by new deposits.
    /// @param newShareLimit The new share limit
    function setShareLimit(uint256 newShareLimit) external;

    /// @notice Sets the recovery mode status.
    /// @param enabled True to enable recovery mode, false to disable.
    function setRecoveryMode(bool enabled) external;
}
