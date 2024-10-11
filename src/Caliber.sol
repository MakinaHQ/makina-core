// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ICaliber} from "./interfaces/ICaliber.sol";

contract Caliber is AccessManagedUpgradeable, ICaliber {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @custom:storage-location erc7201:makina.storage.Caliber
    struct CaliberStorage {
        address _hubMachine;
        address _accountingToken;
        address _oracleRegistry;
        address _mechanic;
        mapping(address bt => uint256 posId) _baseTokenToPositionId;
        mapping(uint256 posId => address bt) _positionIdToBaseToken;
        mapping(uint256 posId => Position pos) _positionById;
        EnumerableSet.UintSet _positionIds;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.Caliber")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CaliberStorageLocation = 0x32461bf02c7aa4aa351cd04411b6c7b9348073fbccf471c7b347bdaada044b00;

    function _getCaliberStorage() private pure returns (CaliberStorage storage $) {
        assembly {
            $.slot := CaliberStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address hubMachine_,
        address accountingToken_,
        uint256 acountingTokenPosID_,
        address oracleRegistry_,
        address initialMechanic_,
        address initialAuthority_
    ) public initializer {
        CaliberStorage storage $ = _getCaliberStorage();
        $._hubMachine = hubMachine_;
        $._accountingToken = accountingToken_;
        _addBaseToken(accountingToken_, acountingTokenPosID_);
        $._oracleRegistry = oracleRegistry_;
        $._mechanic = initialMechanic_;
        __AccessManaged_init(initialAuthority_);
    }

    modifier onlyMechanic() {
        if (msg.sender != _getCaliberStorage()._mechanic) {
            revert NotMechanic();
        }
        _;
    }

    /// @inheritdoc ICaliber
    function hubMachine() public view override returns (address) {
        return _getCaliberStorage()._hubMachine;
    }

    /// @inheritdoc ICaliber
    function mechanic() public view override returns (address) {
        return _getCaliberStorage()._mechanic;
    }

    /// @inheritdoc ICaliber
    function oracleRegistry() public view override returns (address) {
        return _getCaliberStorage()._oracleRegistry;
    }

    /// @inheritdoc ICaliber
    function accountingToken() public view override returns (address) {
        return _getCaliberStorage()._accountingToken;
    }

    /// @inheritdoc ICaliber
    function getPositionsLength() public view override returns (uint256) {
        return _getCaliberStorage()._positionIds.length();
    }

    /// @inheritdoc ICaliber
    function getPositionId(uint256 idx) public view override returns (uint256) {
        return _getCaliberStorage()._positionIds.at(idx);
    }

    /// @inheritdoc ICaliber
    function getPosition(uint256 posId) public view override returns (Position memory) {
        return _getCaliberStorage()._positionById[posId];
    }

    /// @inheritdoc ICaliber
    function isBaseToken(address token) public view override returns (bool) {
        return _getCaliberStorage()._baseTokenToPositionId[token] != 0;
    }

    /// @inheritdoc ICaliber
    function addBaseToken(address token, uint256 positionId) public override restricted {
        _addBaseToken(token, positionId);
    }

    /// @inheritdoc ICaliber
    function setMechanic(address newMechanic) public override restricted {
        CaliberStorage storage $ = _getCaliberStorage();
        address currentMechanic = $._mechanic;
        emit MechanicChanged(currentMechanic, newMechanic);
        $._mechanic = newMechanic;
    }

    function _addBaseToken(address token, uint256 posId) internal {
        CaliberStorage storage $ = _getCaliberStorage();
        $._baseTokenToPositionId[token] = posId;
        $._positionIdToBaseToken[posId] = token;

        Position memory pos = Position({lastAccounted: 0, value: 0, isBaseToken: true});
        _addPosition(pos, posId);
    }

    function _addPosition(Position memory pos, uint256 posId) internal {
        if (posId == 0) {
            revert ZeroPositionID();
        }
        CaliberStorage storage $ = _getCaliberStorage();
        if ($._positionIds.contains(posId)) {
            revert PositionAlreadyExists();
        }
        $._positionIds.add(posId);
        $._positionById[posId] = pos;
        emit PositionAdded(posId, pos.isBaseToken);
    }
}
