// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {ICaliber} from "../interfaces/ICaliber.sol";
import {ICaliberMailbox, IMachineEndpoint} from "../interfaces/ICaliberMailbox.sol";
import {IMachineEndpoint} from "../interfaces/IMachineEndpoint.sol";
import {ISpokeRegistry} from "../interfaces/ISpokeRegistry.sol";

contract CaliberMailbox is Initializable, ICaliberMailbox {
    address public immutable registry;
    uint256 public immutable hubChainId;

    /// @custom:storage-location erc7201:makina.storage.CaliberMailbox
    struct CaliberMailboxStorage {
        address _hubMachine;
        address _caliber;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.CaliberMailbox")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CaliberMailboxStorageLocation =
        0xc8f2c10c9147366283b13eb82b7eca93d88636f13eec15d81ed4c6aa5006aa00;

    bytes32 private constant ACCOUNTING_OUTPUT_STATE_END_OF_ARGS = bytes32(type(uint256).max);

    function _getCaliberStorage() private pure returns (CaliberMailboxStorage storage $) {
        assembly {
            $.slot := CaliberMailboxStorageLocation
        }
    }

    constructor(address _registry, uint256 _hubChainId) {
        registry = _registry;
        hubChainId = _hubChainId;
        _disableInitializers();
    }

    function initialize(address _hubMachine) external override initializer {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        $._hubMachine = _hubMachine;
    }

    modifier onlyFactory() {
        if (msg.sender != ISpokeRegistry(registry).caliberFactory()) {
            revert NotFactory();
        }
        _;
    }

    /// @inheritdoc ICaliberMailbox
    function caliber() external view override returns (address) {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        return $._caliber;
    }

    /// @inheritdoc ICaliberMailbox
    function getSpokeCaliberAccountingData() external view override returns (SpokeCaliberAccountingData memory data) {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        (data.netAum, data.positions, data.baseTokens) = ICaliber($._caliber).getDetailedAum();
        // @TODO include totalReceivedFromHM and totalSentToHM
    }

    /// @inheritdoc ICaliberMailbox
    function setCaliber(address _caliber) external override onlyFactory {
        CaliberMailboxStorage storage $ = _getCaliberStorage();
        if ($._caliber != address(0)) {
            revert CaliberAlreadySet();
        }
        $._caliber = _caliber;
    }

    /// @inheritdoc IMachineEndpoint
    function manageTransfer(address token, uint256 amount, bytes calldata data) external override {}
}
