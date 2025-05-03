// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IBaseMakinaRegistry} from "../../interfaces/IBaseMakinaRegistry.sol";
import {IBridgeAdapter} from "../../interfaces/IBridgeAdapter.sol";
import {IBridgeController} from "../../interfaces/IBridgeController.sol";
import {IBridgeAdapterFactory} from "../../interfaces/IBridgeAdapterFactory.sol";
import {MakinaContext} from "../../utils/MakinaContext.sol";

abstract contract BridgeController is AccessManagedUpgradeable, MakinaContext, IBridgeController {
    using Math for uint256;
    using SafeERC20 for IERC20;

    /// @dev Full scale value in basis points
    uint256 private constant MAX_BPS = 10_000;

    /// @custom:storage-location erc7201:makina.storage.BridgeController
    struct BridgeControllerStorage {
        IBridgeAdapter.Bridge[] _supportedBridges;
        mapping(IBridgeAdapter.Bridge bridgeId => address adapter) _bridgeAdapters;
        mapping(IBridgeAdapter.Bridge bridgeId => uint256 maxBridgeLossBps) _maxBridgeLossBps;
        mapping(IBridgeAdapter.Bridge bridgeId => bool isOutTransferEnabled) _isOutTransferEnabled;
        mapping(address addr => bool isAdapter) _isBridgeAdapter;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.BridgeController")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BridgeControllerStorageLocation =
        0x7363d524082cdf545f1ac33985598b84d2470b8b4fbcc6cb47698cc1b2a03500;

    function _getBridgeControllerStorage() internal pure returns (BridgeControllerStorage storage $) {
        assembly {
            $.slot := BridgeControllerStorageLocation
        }
    }

    /// @inheritdoc IBridgeController
    function isBridgeSupported(IBridgeAdapter.Bridge bridgeId) external view override returns (bool) {
        return _getBridgeControllerStorage()._bridgeAdapters[bridgeId] != address(0);
    }

    /// @inheritdoc IBridgeController
    function isOutTransferEnabled(IBridgeAdapter.Bridge bridgeId) external view override returns (bool) {
        return _getBridgeControllerStorage()._isOutTransferEnabled[bridgeId];
    }

    /// @inheritdoc IBridgeController
    function getBridgeAdapter(IBridgeAdapter.Bridge bridgeId) public view override returns (address) {
        BridgeControllerStorage storage $ = _getBridgeControllerStorage();
        if ($._bridgeAdapters[bridgeId] == address(0)) {
            revert BridgeAdapterDoesNotExist();
        }
        return $._bridgeAdapters[bridgeId];
    }

    /// @inheritdoc IBridgeController
    function getMaxBridgeLossBps(IBridgeAdapter.Bridge bridgeId) external view returns (uint256) {
        BridgeControllerStorage storage $ = _getBridgeControllerStorage();
        if ($._bridgeAdapters[bridgeId] == address(0)) {
            revert BridgeAdapterDoesNotExist();
        }
        return $._maxBridgeLossBps[bridgeId];
    }

    /// @inheritdoc IBridgeController
    function createBridgeAdapter(
        IBridgeAdapter.Bridge bridgeId,
        uint256 initialMaxBridgeLossBps,
        bytes calldata initData
    ) external restricted returns (address) {
        BridgeControllerStorage storage $ = _getBridgeControllerStorage();

        if ($._bridgeAdapters[bridgeId] != address(0)) {
            revert BridgeAdapterAlreadyExists();
        }

        address bridgeAdapter =
            IBridgeAdapterFactory(IBaseMakinaRegistry(registry).coreFactory()).createBridgeAdapter(bridgeId, initData);

        $._bridgeAdapters[bridgeId] = bridgeAdapter;
        $._maxBridgeLossBps[bridgeId] = initialMaxBridgeLossBps;
        $._isOutTransferEnabled[bridgeId] = true;
        $._isBridgeAdapter[bridgeAdapter] = true;
        $._supportedBridges.push(bridgeId);

        emit BridgeAdapterCreated(uint256(bridgeId), bridgeAdapter);

        return bridgeAdapter;
    }

    function _setOutTransferEnabled(IBridgeAdapter.Bridge bridgeId, bool enabled) internal {
        BridgeControllerStorage storage $ = _getBridgeControllerStorage();
        if ($._bridgeAdapters[bridgeId] == address(0)) {
            revert BridgeAdapterDoesNotExist();
        }
        emit SetOutTransferEnabled(uint256(bridgeId), enabled);
        $._isOutTransferEnabled[bridgeId] = enabled;
    }

    function _setMaxBridgeLossBps(IBridgeAdapter.Bridge bridgeId, uint256 maxBridgeLossBps) internal {
        BridgeControllerStorage storage $ = _getBridgeControllerStorage();
        if ($._bridgeAdapters[bridgeId] == address(0)) {
            revert BridgeAdapterDoesNotExist();
        }
        emit MaxBridgeLossBpsChange(uint256(bridgeId), $._maxBridgeLossBps[bridgeId], maxBridgeLossBps);
        $._maxBridgeLossBps[bridgeId] = maxBridgeLossBps;
    }

    function _isBridgeAdapter(address adapter) internal view returns (bool) {
        return _getBridgeControllerStorage()._isBridgeAdapter[adapter];
    }

    function _scheduleOutBridgeTransfer(
        IBridgeAdapter.Bridge bridgeId,
        uint256 destinationChainId,
        address recipient,
        address inputToken,
        uint256 inputAmount,
        address outputToken,
        uint256 minOutputAmount
    ) internal {
        BridgeControllerStorage storage $ = _getBridgeControllerStorage();
        address adapter = getBridgeAdapter(bridgeId);
        if (!$._isOutTransferEnabled[bridgeId]) {
            revert OutTransferDisabled();
        }
        if (minOutputAmount < inputAmount.mulDiv(MAX_BPS - $._maxBridgeLossBps[bridgeId], MAX_BPS)) {
            revert MaxValueLossExceeded();
        }
        if (minOutputAmount > inputAmount) {
            revert MinOutputAmountExceedsInputAmount();
        }
        IERC20(inputToken).forceApprove(adapter, inputAmount);
        IBridgeAdapter(adapter).scheduleOutBridgeTransfer(
            destinationChainId, recipient, inputToken, inputAmount, outputToken, minOutputAmount
        );
    }

    function _sendOutBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId, bytes calldata data) internal {
        address adapter = getBridgeAdapter(bridgeId);
        if (!_getBridgeControllerStorage()._isOutTransferEnabled[bridgeId]) {
            revert OutTransferDisabled();
        }
        IBridgeAdapter(adapter).sendOutBridgeTransfer(transferId, data);
    }

    function _authorizeInBridgeTransfer(IBridgeAdapter.Bridge bridgeId, bytes32 messageHash) internal {
        address adapter = getBridgeAdapter(bridgeId);
        IBridgeAdapter(adapter).authorizeInBridgeTransfer(messageHash);
    }

    function _claimInBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId) internal {
        address adapter = getBridgeAdapter(bridgeId);
        IBridgeAdapter(adapter).claimInBridgeTransfer(transferId);
    }

    function _cancelOutBridgeTransfer(IBridgeAdapter.Bridge bridgeId, uint256 transferId) internal {
        address adapter = getBridgeAdapter(bridgeId);
        IBridgeAdapter(adapter).cancelOutBridgeTransfer(transferId);
    }
}
