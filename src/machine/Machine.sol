// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";
import {EthCallQueryResponse} from "@wormhole/sdk/libraries/QueryResponse.sol";
import {QueryResponse} from "@wormhole/sdk/libraries/QueryResponse.sol";
import {QueryResponseLib} from "@wormhole/sdk/libraries/QueryResponse.sol";

import {ICaliber} from "../interfaces/ICaliber.sol";
import {IChainRegistry} from "../interfaces/IChainRegistry.sol";
import {IHubDualMailbox} from "../interfaces/IHubDualMailbox.sol";
import {IHubRegistry} from "../interfaces/IHubRegistry.sol";
import {IMachine} from "../interfaces/IMachine.sol";
import {IMachineShare} from "../interfaces/IMachineShare.sol";
import {IMachineMailbox} from "../interfaces/IMachineMailbox.sol";
import {IOracleRegistry} from "../interfaces/IOracleRegistry.sol";
import {IOwnable2Step} from "../interfaces/IOwnable2Step.sol";
import {ISpokeCaliberMailbox} from "../interfaces/ISpokeCaliberMailbox.sol";
import {ISpokeMachineMailbox} from "../interfaces/ISpokeMachineMailbox.sol";
import {Constants} from "../libraries/Constants.sol";

contract Machine is AccessManagedUpgradeable, IMachine {
    using Math for uint256;
    using SafeERC20 for IERC20Metadata;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IMachine
    address public immutable registry;

    /// @inheritdoc IMachine
    address public immutable wormhole;

    /// @custom:storage-location erc7201:makina.storage.Machine
    struct MachineStorage {
        address _shareToken;
        address _accountingToken;
        address _mechanic;
        address _securityCouncil;
        address _depositor;
        uint256 _caliberStaleThreshold;
        uint256 _lastTotalAum;
        uint256 _lastGlobalAccountingTime;
        uint256 _shareTokenDecimalsOffset;
        uint256 _shareLimit;
        bool _depositorOnlyMode;
        bool _recoveryMode;
        uint256 _hubChainId;
        address _hubCaliberMailbox;
        uint256[] _foreignChainIds;
        mapping(uint256 foreignChainId => SpokeCaliberData) _foreignChainIdToSpokeCaliberData;
        mapping(address addr => bool isMailbox) _isMachineMailbox;
        EnumerableSet.AddressSet _idleTokens;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.Machine")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MachineStorageLocation = 0x55fe2a17e400bcd0e2125123a7fc955478e727b29a4c522f4f2bd95d961bd900;

    function _getMachineStorage() private pure returns (MachineStorage storage $) {
        assembly {
            $.slot := MachineStorageLocation
        }
    }

    constructor(address _registry, address _wormhole) {
        registry = _registry;
        wormhole = _wormhole;
        _disableInitializers();
    }

    /// @inheritdoc IMachine
    function initialize(MachineInitParams calldata params, address _shareToken) external override initializer {
        MachineStorage storage $ = _getMachineStorage();

        uint256 atDecimals = IERC20Metadata(params.accountingToken).decimals();
        uint256 stDecimals = IERC20Metadata(_shareToken).decimals();
        if (
            atDecimals < Constants.MIN_ACCOUNTING_TOKEN_DECIMALS || atDecimals > Constants.MAX_ACCOUNTING_TOKEN_DECIMALS
                || stDecimals < atDecimals
        ) {
            revert InvalidDecimals();
        }
        // Reverts if no price feed is registered for token in the oracle registry.
        IOracleRegistry(IHubRegistry(registry).oracleRegistry()).getTokenFeedData(params.accountingToken);
        $._accountingToken = params.accountingToken;
        $._idleTokens.add(params.accountingToken);

        IOwnable2Step(_shareToken).acceptOwnership();
        $._shareToken = _shareToken;
        $._shareTokenDecimalsOffset = stDecimals - atDecimals;

        $._mechanic = params.initialMechanic;
        $._securityCouncil = params.initialSecurityCouncil;
        $._depositor = params.depositor;
        $._caliberStaleThreshold = params.initialCaliberStaleThreshold;
        $._shareLimit = params.initialShareLimit;
        $._depositorOnlyMode = params.depositorOnlyMode;
        __AccessManaged_init(params.initialAuthority);

        $._hubChainId = block.chainid;
        address mailbox = _deployHubCaliber(params);
        $._hubCaliberMailbox = mailbox;
        $._isMachineMailbox[mailbox] = true;
    }

    modifier onlyOperator() {
        MachineStorage storage $ = _getMachineStorage();
        if (msg.sender != ($._recoveryMode ? $._securityCouncil : $._mechanic)) {
            revert UnauthorizedOperator();
        }
        _;
    }

    modifier onlyMailbox() {
        MachineStorage storage $ = _getMachineStorage();
        if (!$._isMachineMailbox[msg.sender]) {
            revert NotMailbox();
        }
        _;
    }

    modifier onlyAllowedDepositor() {
        MachineStorage storage $ = _getMachineStorage();
        if ($._depositorOnlyMode && msg.sender != $._depositor) {
            revert UnauthorizedDepositor();
        }
        _;
    }

    modifier notRecoveryMode() {
        MachineStorage storage $ = _getMachineStorage();
        if ($._recoveryMode) {
            revert RecoveryMode();
        }
        _;
    }

    /// @inheritdoc IMachine
    function mechanic() external view override returns (address) {
        return _getMachineStorage()._mechanic;
    }

    /// @inheritdoc IMachine
    function securityCouncil() public view override returns (address) {
        return _getMachineStorage()._securityCouncil;
    }

    /// @inheritdoc IMachine
    function shareToken() external view override returns (address) {
        return _getMachineStorage()._shareToken;
    }

    /// @inheritdoc IMachine
    function accountingToken() external view override returns (address) {
        return _getMachineStorage()._accountingToken;
    }

    /// @inheritdoc IMachine
    function hubCaliberMailbox() external view returns (address) {
        return _getMachineStorage()._hubCaliberMailbox;
    }

    /// @inheritdoc IMachine
    function caliberStaleThreshold() external view override returns (uint256) {
        return _getMachineStorage()._caliberStaleThreshold;
    }

    /// @inheritdoc IMachine
    function shareLimit() external view override returns (uint256) {
        return _getMachineStorage()._shareLimit;
    }

    /// @inheritdoc IMachine
    function maxMint() public view override returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        if ($._shareLimit == type(uint256).max) {
            return type(uint256).max;
        }
        uint256 totalSupply = IERC20Metadata($._shareToken).totalSupply();
        return totalSupply < $._shareLimit ? $._shareLimit - totalSupply : 0;
    }

    /// @inheritdoc IMachine
    function depositorOnlyMode() external view override returns (bool) {
        return _getMachineStorage()._depositorOnlyMode;
    }

    /// @inheritdoc IMachine
    function recoveryMode() public view override returns (bool) {
        return _getMachineStorage()._recoveryMode;
    }

    /// @inheritdoc IMachine
    function lastTotalAum() external view override returns (uint256) {
        return _getMachineStorage()._lastTotalAum;
    }

    /// @inheritdoc IMachine
    function lastGlobalAccountingTime() external view override returns (uint256) {
        return _getMachineStorage()._lastGlobalAccountingTime;
    }

    /// @inheritdoc IMachine
    function getSpokeCalibersLength() external view override returns (uint256) {
        return _getMachineStorage()._foreignChainIds.length;
    }

    /// @inheritdoc IMachine
    function getSpokeChainId(uint256 idx) external view override returns (uint256) {
        return _getMachineStorage()._foreignChainIds[idx];
    }

    /// @inheritdoc IMachine
    function getSpokeCaliberAccountingData(uint256 chainId) external view override returns (SpokeCaliberData memory) {
        return _getMachineStorage()._foreignChainIdToSpokeCaliberData[chainId];
    }

    /// @inheritdoc IMachine
    function isIdleToken(address token) external view override returns (bool) {
        return _getMachineStorage()._idleTokens.contains(token);
    }

    /// @inheritdoc IMachine
    function convertToShares(uint256 assets) external view override returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /// @inheritdoc IMachine
    function notifyIncomingTransfer(address token) external override onlyMailbox {
        if (IERC20Metadata(token).balanceOf(address(this)) > 0) {
            MachineStorage storage $ = _getMachineStorage();
            bool newlyAdded = $._idleTokens.add(token);
            if (newlyAdded) {
                // Reverts if no price feed is registered for token in the oracle registry.
                IOracleRegistry(IHubRegistry(registry).oracleRegistry()).getTokenFeedData(token);
            }
        }
    }

    /// @inheritdoc IMachine
    function transferToCaliber(address token, uint256 amount, uint256 /*chainId*/ )
        external
        override
        notRecoveryMode
        onlyOperator
    {
        MachineStorage storage $ = _getMachineStorage();

        address mailbox = $._hubCaliberMailbox;

        // @TODO implement fund bridging to spoke calibers

        IERC20Metadata(token).forceApprove(mailbox, amount);
        emit TransferToCaliber($._hubChainId, token, amount);
        IMachineMailbox(mailbox).manageTransferFromMachineToCaliber(token, amount);
        if (IERC20Metadata(token).balanceOf(address(this)) == 0 && token != $._accountingToken) {
            $._idleTokens.remove(token);
        }
    }

    /// @inheritdoc IMachine
    function updateTotalAum() external override notRecoveryMode returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        uint256 totalAum = _getTotalAum();
        uint256 currentTimestamp = block.timestamp;
        emit TotalAumUpdated(totalAum, currentTimestamp);
        $._lastTotalAum = totalAum;
        $._lastGlobalAccountingTime = currentTimestamp;
        return totalAum;
    }

    /// @inheritdoc IMachine
    function deposit(uint256 assets, address receiver)
        external
        notRecoveryMode
        onlyAllowedDepositor
        returns (uint256)
    {
        MachineStorage storage $ = _getMachineStorage();
        uint256 shares = _convertToShares(assets, Math.Rounding.Floor);
        uint256 _maxMint = maxMint();
        if (shares > _maxMint) {
            revert ExceededMaxMint(shares, _maxMint);
        }

        IERC20Metadata($._accountingToken).safeTransferFrom(msg.sender, address(this), assets);
        IMachineShare($._shareToken).mint(receiver, shares);
        $._lastTotalAum += assets;
        emit Deposit(msg.sender, receiver, assets, shares);

        return shares;
    }

    function updateSpokeCaliberAccountingData(bytes memory response, IWormhole.Signature[] memory signatures)
        external
    {
        MachineStorage storage $ = _getMachineStorage();

        QueryResponse memory r = QueryResponseLib.parseAndVerifyQueryResponse(wormhole, response, signatures);
        uint256 numResponses = r.responses.length;

        for (uint256 i; i < numResponses;) {
            uint16 _wmChainId = r.responses[i].chainId;
            uint256 _evmChainId = IChainRegistry(IHubRegistry(registry).chainRegistry()).whToEvmChainId(_wmChainId);
            SpokeCaliberData storage caliberData = $._foreignChainIdToSpokeCaliberData[_evmChainId];
            if (caliberData.machineMailbox == address(0)) {
                revert InvalidChainId();
            }

            EthCallQueryResponse memory eqr = QueryResponseLib.parseEthCallQueryResponse(r.responses[i]);

            // Validate that update is not older than current chain last update, nor stale.
            uint256 responseTimestamp = eqr.blockTime / QueryResponseLib.MICROSECONDS_PER_SECOND;
            if (
                responseTimestamp < caliberData.timestamp
                    || (
                        block.timestamp > responseTimestamp
                            && block.timestamp - responseTimestamp >= $._caliberStaleThreshold
                    )
            ) {
                revert StaleData();
            }

            // Validate that only one result is returned.
            if (eqr.results.length != 1) {
                revert UnexpectedResultLength();
            }

            // Validate addresses and function signatures.
            address[] memory validAddresses = new address[](1);
            bytes4[] memory validFunctionSignatures = new bytes4[](1);
            validAddresses[0] = ISpokeMachineMailbox(caliberData.machineMailbox).spokeCaliberMailbox();
            validFunctionSignatures[0] = ISpokeCaliberMailbox.getSpokeCaliberAccountingData.selector;
            QueryResponseLib.validateEthCallRecord(eqr.results[0], validAddresses, validFunctionSignatures);

            // Decode and update accounting data.
            ISpokeCaliberMailbox.SpokeCaliberAccountingData memory accountingData =
                abi.decode(eqr.results[0].result, (ISpokeCaliberMailbox.SpokeCaliberAccountingData));
            caliberData.netAum = accountingData.netAum;
            caliberData.positions = accountingData.positions;
            caliberData.totalReceivedFromHM = accountingData.totalReceivedFromHM;
            caliberData.totalSentToHM = accountingData.totalSentToHM;
            caliberData.timestamp = responseTimestamp;

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IMachine
    function createSpokeMailbox(uint256 chainId) external restricted returns (address) {
        MachineStorage storage $ = _getMachineStorage();
        if ($._foreignChainIdToSpokeCaliberData[chainId].machineMailbox != address(0)) {
            revert SpokeMailboxAlreadyExists();
        }
        address mailbox = address(
            new BeaconProxy(
                IHubRegistry(registry).spokeMachineMailboxBeacon(),
                abi.encodeCall(ISpokeMachineMailbox.initialize, (address(this), $._hubChainId))
            )
        );

        $._isMachineMailbox[mailbox] = true;
        $._foreignChainIds.push(chainId);
        SpokeCaliberData storage data = $._foreignChainIdToSpokeCaliberData[chainId];
        data.machineMailbox = mailbox;
        emit SpokeMailboxDeployed(mailbox, chainId);

        return mailbox;
    }

    /// @inheritdoc IMachine
    function setSpokeCaliberMailbox(uint256 chainId, address spokeCaliberMailbox) external restricted {
        MachineStorage storage $ = _getMachineStorage();
        SpokeCaliberData storage data = $._foreignChainIdToSpokeCaliberData[chainId];
        if (data.machineMailbox == address(0)) {
            revert SpokeMailboxDoesNotExist();
        }
        ISpokeMachineMailbox(data.machineMailbox).setSpokeCaliberMailbox(spokeCaliberMailbox);
    }

    /// @inheritdoc IMachine
    function setMechanic(address newMechanic) public override restricted {
        MachineStorage storage $ = _getMachineStorage();
        emit MechanicChanged($._mechanic, newMechanic);
        $._mechanic = newMechanic;
    }

    /// @inheritdoc IMachine
    function setSecurityCouncil(address newSecurityCouncil) public override restricted {
        MachineStorage storage $ = _getMachineStorage();
        emit SecurityCouncilChanged($._securityCouncil, newSecurityCouncil);
        $._securityCouncil = newSecurityCouncil;
    }

    /// @inheritdoc IMachine
    function setCaliberStaleThreshold(uint256 newCaliberStaleThreshold) public override restricted {
        MachineStorage storage $ = _getMachineStorage();
        emit CaliberStaleThresholdChanged($._caliberStaleThreshold, newCaliberStaleThreshold);
        $._caliberStaleThreshold = newCaliberStaleThreshold;
    }

    /// @inheritdoc IMachine
    function setShareLimit(uint256 newShareLimit) public override restricted {
        MachineStorage storage $ = _getMachineStorage();
        emit ShareLimitChanged($._shareLimit, newShareLimit);
        $._shareLimit = newShareLimit;
    }

    /// @inheritdoc IMachine
    function setDepositorOnlyMode(bool enabled) public restricted {
        MachineStorage storage $ = _getMachineStorage();
        if ($._depositorOnlyMode != enabled) {
            $._depositorOnlyMode = enabled;
            emit DepositorOnlyModeChanged(enabled);
        }
    }

    /// @inheritdoc IMachine
    function setRecoveryMode(bool enabled) public override restricted {
        MachineStorage storage $ = _getMachineStorage();
        if ($._recoveryMode != enabled) {
            $._recoveryMode = enabled;
            emit RecoveryModeChanged(enabled);
        }
    }

    /// @dev Deploys the hub caliber and associated dual mailbox.
    /// @return mailbox The address of the mailbox.
    function _deployHubCaliber(MachineInitParams calldata params) internal onlyInitializing returns (address) {
        ICaliber.CaliberInitParams memory initParams = ICaliber.CaliberInitParams({
            hubMachineEndpoint: address(this),
            accountingToken: params.accountingToken,
            initialPositionStaleThreshold: params.hubCaliberPosStaleThreshold,
            initialAllowedInstrRoot: params.hubCaliberAllowedInstrRoot,
            initialTimelockDuration: params.hubCaliberTimelockDuration,
            initialMaxPositionIncreaseLossBps: params.hubCaliberMaxPositionIncreaseLossBps,
            initialMaxPositionDecreaseLossBps: params.hubCaliberMaxPositionDecreaseLossBps,
            initialMaxSwapLossBps: params.hubCaliberMaxSwapLossBps,
            initialFlashLoanModule: params.hubCaliberInitialFlashLoanModule,
            initialMechanic: params.initialMechanic,
            initialSecurityCouncil: params.initialSecurityCouncil,
            initialAuthority: authority()
        });
        address caliber = address(
            new BeaconProxy(
                IHubRegistry(registry).caliberBeacon(),
                abi.encodeCall(ICaliber.initialize, (initParams, IHubRegistry(registry).hubDualMailboxBeacon()))
            )
        );
        address mailbox = ICaliber(caliber).mailbox();
        emit HubCaliberDeployed(caliber, mailbox);
        return mailbox;
    }

    /// @dev Computes the total AUM of the machine.
    function _getTotalAum() internal view returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        uint256 totalAum;

        // local caliber net AUM
        totalAum += IHubDualMailbox($._hubCaliberMailbox).getHubCaliberAccountingData().netAum;

        uint256 currentTimestamp = block.timestamp;
        uint256 len = $._foreignChainIds.length;
        for (uint256 i; i < len;) {
            uint256 chainId = $._foreignChainIds[i];
            SpokeCaliberData memory spokeCaliberData = $._foreignChainIdToSpokeCaliberData[chainId];
            if (
                currentTimestamp > spokeCaliberData.timestamp
                    && currentTimestamp - spokeCaliberData.timestamp > $._caliberStaleThreshold
            ) {
                revert CaliberAccountingStale(chainId);
            }
            totalAum += spokeCaliberData.netAum;
            // @TODO take async fund bridging into account

            unchecked {
                ++i;
            }
        }

        // idle tokens
        len = $._idleTokens.length();
        for (uint256 i; i < len;) {
            address token = $._idleTokens.at(i);
            totalAum += _accountingValueOf(token, IERC20Metadata(token).balanceOf(address(this)));
            unchecked {
                ++i;
            }
        }
        return totalAum;
    }

    /// @dev Computes the accounting value of a given token amount.
    function _accountingValueOf(address token, uint256 amount) internal view returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        uint256 price = IOracleRegistry(IHubRegistry(registry).oracleRegistry()).getPrice(token, $._accountingToken);
        return amount.mulDiv(price, (10 ** IERC20Metadata(token).decimals()));
    }

    /// @dev Converts accounting token amount to share amount, with support for rounding direction.
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        return assets.mulDiv(
            IERC20Metadata($._shareToken).totalSupply() + 10 ** $._shareTokenDecimalsOffset,
            $._lastTotalAum + 1,
            rounding
        );
    }
}
