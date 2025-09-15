// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICaliberFactory} from "../interfaces/ICaliberFactory.sol";
import {ICoreRegistry} from "../interfaces/ICoreRegistry.sol";
import {ISwapModule} from "../interfaces/ISwapModule.sol";
import {MakinaContext} from "../utils/MakinaContext.sol";
import {Errors} from "../libraries/Errors.sol";

contract SwapModule is AccessManagedUpgradeable, MakinaContext, ISwapModule {
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:makina.storage.SwapModule
    struct SwapModuleStorage {
        mapping(uint16 swapperId => SwapperTargets targets) _swapperTargets;
    }

    // keccak256(abi.encode(uint256(keccak256("makina.storage.SwapModule")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SwapModuleStorageLocation =
        0x2964c0594a3da0414db90b8d5f6c112accd22109f0399a98ea4b239ff3f7a200;

    function _getSwapModuleStorage() private pure returns (SwapModuleStorage storage $) {
        assembly {
            $.slot := SwapModuleStorageLocation
        }
    }

    constructor(address _registry) MakinaContext(_registry) {
        _disableInitializers();
    }

    function initialize(address _initialAuthority) external initializer {
        __AccessManaged_init(_initialAuthority);
    }

    /// @inheritdoc ISwapModule
    function getSwapperTargets(uint16 swapperId)
        external
        view
        returns (address approvalTarget, address executionTarget)
    {
        SwapperTargets storage targets = _getSwapModuleStorage()._swapperTargets[swapperId];
        return (targets.approvalTarget, targets.executionTarget);
    }

    /// @inheritdoc ISwapModule
    function swap(SwapOrder calldata order) external override returns (uint256) {
        if (!ICaliberFactory(ICoreRegistry(registry).coreFactory()).isCaliber(msg.sender)) {
            revert Errors.NotCaliber();
        }

        SwapperTargets storage targets = _getSwapModuleStorage()._swapperTargets[order.swapperId];

        address approvalTarget = targets.approvalTarget;
        address executionTarget = targets.executionTarget;

        if (approvalTarget == address(0) || executionTarget == address(0)) {
            revert Errors.SwapperTargetsNotSet();
        }

        address caller = msg.sender;
        IERC20(order.inputToken).safeTransferFrom(caller, address(this), order.inputAmount);

        uint256 balBefore = IERC20(order.outputToken).balanceOf(address(this));

        IERC20(order.inputToken).forceApprove(approvalTarget, order.inputAmount);
        // solhint-disable-next-line
        (bool success,) = executionTarget.call(order.data);
        if (!success) {
            revert Errors.SwapFailed();
        }
        IERC20(order.inputToken).forceApprove(approvalTarget, 0);

        uint256 outputAmount = IERC20(order.outputToken).balanceOf(address(this)) - balBefore;

        if (outputAmount < order.minOutputAmount) {
            revert Errors.AmountOutTooLow();
        }
        IERC20(order.outputToken).safeTransfer(caller, outputAmount);

        emit Swap(caller, order.swapperId, order.inputToken, order.outputToken, order.inputAmount, outputAmount);

        return outputAmount;
    }

    /// @inheritdoc ISwapModule
    function setSwapperTargets(uint16 swapperId, address approvalTarget, address executionTarget)
        external
        override
        restricted
    {
        _getSwapModuleStorage()._swapperTargets[swapperId] = SwapperTargets(approvalTarget, executionTarget);
        emit SwapperTargetsSet(swapperId, approvalTarget, executionTarget);
    }
}
