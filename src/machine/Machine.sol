// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberFactory} from "../interfaces/ICaliberFactory.sol";
import {IHubRegistry} from "../interfaces/IHubRegistry.sol";
import {IMachine} from "../interfaces/IMachine.sol";
import {IMachineMailbox} from "../interfaces/IMachineMailbox.sol";
import {IOracleRegistry} from "../interfaces/IOracleRegistry.sol";

contract Machine is AccessManagedUpgradeable, IMachine {
    using Math for uint256;
    using SafeERC20 for IERC20Metadata;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IMachine
    address public immutable registry;

    /// @custom:storage-location erc7201:makina.storage.Machine
    struct MachineStorage {
        address _accountingToken;
        address _mechanic;
        address _securityCouncil;
        uint256 _caliberStaleThreshold;
        uint256 _lastReportedTotalAum;
        uint256 _lastReportedTotalAumTime;
        uint256 _sharePrice;
        bool _recoveryMode;
        mapping(uint256 chainId => address mailbox) _chainIdToMailbox;
        mapping(address mailbox => uint256 chainId) _mailboxToChainId;
        uint256[] _supportedChainIds;
        EnumerableSet.AddressSet _idleTokens;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.Machine")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MachineStorageLocation = 0x55fe2a17e400bcd0e2125123a7fc955478e727b29a4c522f4f2bd95d961bd900;

    function _getMachineStorage() private pure returns (MachineStorage storage $) {
        assembly {
            $.slot := MachineStorageLocation
        }
    }

    constructor(address _registry) {
        registry = _registry;
        _disableInitializers();
    }

    /// @inheritdoc IMachine
    function initialize(MachineInitParams calldata params) external override initializer {
        MachineStorage storage $ = _getMachineStorage();

        // Reverts if no price feed is registered for token in the oracle registry.
        IOracleRegistry(IHubRegistry(registry).oracleRegistry()).getTokenFeedData(params.accountingToken);
        $._accountingToken = params.accountingToken;
        $._idleTokens.add(params.accountingToken);

        $._mechanic = params.initialMechanic;
        $._securityCouncil = params.initialSecurityCouncil;
        $._caliberStaleThreshold = params.initialCaliberStaleThreshold;
        __AccessManaged_init(params.initialAuthority);

        address mailbox = _deployHubCaliber(params);
        $._chainIdToMailbox[block.chainid] = mailbox;
        $._mailboxToChainId[mailbox] = block.chainid;
        $._supportedChainIds.push(block.chainid);
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
        if ($._mailboxToChainId[msg.sender] == 0) {
            revert NotMailbox();
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
    function accountingToken() external view override returns (address) {
        return _getMachineStorage()._accountingToken;
    }

    /// @inheritdoc IMachine
    function caliberStaleThreshold() external view override returns (uint256) {
        return _getMachineStorage()._caliberStaleThreshold;
    }

    /// @inheritdoc IMachine
    function recoveryMode() public view override returns (bool) {
        return _getMachineStorage()._recoveryMode;
    }

    /// @inheritdoc IMachine
    function lastReportedTotalAum() external view override returns (uint256) {
        return _getMachineStorage()._lastReportedTotalAum;
    }

    /// @inheritdoc IMachine
    function lastReportedTotalAumTime() external view override returns (uint256) {
        return _getMachineStorage()._lastReportedTotalAumTime;
    }

    /// @inheritdoc IMachine
    function getCalibersLength() external view override returns (uint256) {
        return _getMachineStorage()._supportedChainIds.length;
    }

    /// @inheritdoc IMachine
    function getSupportedChainId(uint256 idx) external view override returns (uint256) {
        return _getMachineStorage()._supportedChainIds[idx];
    }

    /// @inheritdoc IMachine
    function getMailbox(uint256 chainId) external view override returns (address) {
        return _getMachineStorage()._chainIdToMailbox[chainId];
    }

    /// @inheritdoc IMachine
    function isIdleToken(address token) external view override returns (bool) {
        return _getMachineStorage()._idleTokens.contains(token);
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
    function transferToCaliber(address token, uint256 amount, uint256 chainId)
        external
        override
        notRecoveryMode
        onlyOperator
    {
        MachineStorage storage $ = _getMachineStorage();
        address mailbox = $._chainIdToMailbox[chainId];
        IERC20Metadata(token).forceApprove(mailbox, amount);
        emit TransferToCaliber(chainId, token, amount);
        IMachineMailbox(mailbox).manageTransferFromMachineToCaliber(token, amount);
        if (IERC20Metadata(token).balanceOf(address(this)) == 0 && token != $._accountingToken) {
            $._idleTokens.remove(token);
        }
    }

    /// @inheritdoc IMachine
    function updateTotalAum() external override notRecoveryMode returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        uint256 totalAum = _getTotalAum();
        uint256 currenTimestamp = block.timestamp;
        emit TotalAumUpdated(totalAum, currenTimestamp);
        $._lastReportedTotalAum = totalAum;
        $._lastReportedTotalAumTime = currenTimestamp;
        return totalAum;
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
    function setRecoveryMode(bool enabled) public override restricted {
        MachineStorage storage $ = _getMachineStorage();
        if ($._recoveryMode != enabled) {
            $._recoveryMode = enabled;
            emit RecoveryModeChanged(enabled);
        }
    }

    /// @dev Deploys the hub caliber and associated dual mailbox
    /// @return mailbox The address of the mailbox
    function _deployHubCaliber(MachineInitParams calldata params) internal onlyInitializing returns (address) {
        ICaliber.InitParams memory caliberParams = ICaliber.InitParams({
            hubMachineEndpoint: address(this),
            mailboxBeacon: IHubRegistry(registry).hubDualMailboxBeacon(),
            accountingToken: params.accountingToken,
            accountingTokenPosId: params.hubCaliberAccountingTokenPosID,
            initialPositionStaleThreshold: params.hubCaliberPosStaleThreshold,
            initialAllowedInstrRoot: params.hubCaliberAllowedInstrRoot,
            initialTimelockDuration: params.hubCaliberTimelockDuration,
            initialMaxMgmtLossBps: params.hubCaliberMaxMgmtLossBps,
            initialMaxSwapLossBps: params.hubCaliberMaxSwapLossBps,
            initialMechanic: params.initialMechanic,
            initialSecurityCouncil: params.initialSecurityCouncil,
            initialAuthority: authority()
        });
        address caliber = address(
            new BeaconProxy(
                IHubRegistry(registry).caliberBeacon(), abi.encodeCall(ICaliber.initialize, (caliberParams))
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

        uint256 len = $._supportedChainIds.length;
        for (uint256 i; i < len; i++) {
            address mailbox = $._chainIdToMailbox[$._supportedChainIds[i]];
            if (block.timestamp - IMachineMailbox(mailbox).lastReportedAumTime() > $._caliberStaleThreshold) {
                revert CaliberAccountingStale($._supportedChainIds[i]);
            }
            // @TODO take async bridging into account in spoke mailboxes
            totalAum += IMachineMailbox(mailbox).lastReportedAum();
        }
        len = $._idleTokens.length();
        for (uint256 i; i < len; i++) {
            address token = $._idleTokens.at(i);
            totalAum += _accountingValueOf(token, IERC20Metadata(token).balanceOf(address(this)));
        }
        return totalAum;
    }

    /// @dev Computes the accounting value of a given token amount.
    function _accountingValueOf(address token, uint256 amount) internal view returns (uint256) {
        MachineStorage storage $ = _getMachineStorage();
        uint256 price = IOracleRegistry(IHubRegistry(registry).oracleRegistry()).getPrice(token, $._accountingToken);
        return amount.mulDiv(price, (10 ** IERC20Metadata(token).decimals()));
    }
}
