// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICctpV2TokenMessenger} from "src/interfaces/ICctpV2TokenMessenger.sol";
import {MockCctpV2TokenMinter} from "./MockCctpV2TokenMinter.sol";

/// @dev MockCctpV2TokenMessenger contract for testing use only
contract MockCctpV2TokenMessenger is ICctpV2TokenMessenger {
    using SafeERC20 for IERC20;

    event DepositForBurnWithHook(bytes32 messageDigest);

    error InvalidMessageBody();
    error InsufficientFee();

    struct RelayMessageParams {
        uint32 sourceDomain;
        uint32 destinationDomain;
        bytes32 destinationCaller;
        uint32 minFinalityThreshold;
        address burnToken;
        bytes32 mintRecipient;
        uint256 amount;
        bytes32 sender;
        uint256 maxFee;
        uint256 feeExecuted;
        bytes hookData;
    }

    uint256 private constant BODY_BURN_TOKEN_INDEX = 4;
    uint8 private constant BODY_MINT_RECIPIENT_INDEX = 36;
    uint8 private constant BODY_AMOUNT_INDEX = 68;
    uint8 public constant BODY_FEE_EXECUTED_INDEX = 164;

    uint32 private sourceDomain;

    address public override localMinter;
    uint256 public minFee;
    address public feeRecipient;

    constructor(address _localMinter, uint256 _minFee, address _feeRecipient) {
        localMinter = _localMinter;
        minFee = _minFee;
        feeRecipient = _feeRecipient;
    }

    function getMinFeeAmount(uint256 amount) external view override returns (uint256) {
        return _calcMinFeeAmount(amount);
    }

    function formatMessageForRelay(RelayMessageParams memory p) public view returns (bytes memory) {
        bytes memory messageBody = abi.encodePacked(
            uint32(2),
            bytes32(uint256(uint160(p.burnToken))),
            p.mintRecipient,
            p.amount,
            p.sender,
            p.maxFee,
            p.feeExecuted,
            uint256(0),
            p.hookData
        );

        bytes32 _this = bytes32(uint256(uint160(address(this))));

        return abi.encodePacked(
            uint32(0),
            p.sourceDomain,
            p.destinationDomain,
            bytes32(0),
            _this,
            _this,
            p.destinationCaller,
            p.minFinalityThreshold,
            uint32(0),
            messageBody
        );
    }

    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hookData
    ) external override {
        if (hookData.length == 0) {
            revert();
        }

        if (minFee > 0 && maxFee < _calcMinFeeAmount(amount)) {
            revert InsufficientFee();
        }

        IERC20(burnToken).safeTransferFrom(msg.sender, localMinter, amount);
        MockCctpV2TokenMinter(localMinter).burn(burnToken, amount);

        emit DepositForBurnWithHook(
            keccak256(
                formatMessageForRelay(
                    RelayMessageParams({
                        sourceDomain: sourceDomain,
                        destinationDomain: destinationDomain,
                        destinationCaller: destinationCaller,
                        minFinalityThreshold: minFinalityThreshold,
                        burnToken: burnToken,
                        mintRecipient: mintRecipient,
                        amount: amount,
                        sender: bytes32(uint256(uint160(msg.sender))),
                        maxFee: maxFee,
                        feeExecuted: 0,
                        hookData: hookData
                    })
                )
            )
        );
    }

    function handleReceiveFinalizedMessage(uint32 remoteDomain, bytes32, uint32, bytes calldata messageBody)
        external
        returns (bool)
    {
        address _mintRecipient = address(uint160(uint256(_readBytes32(messageBody, BODY_MINT_RECIPIENT_INDEX))));
        bytes32 _burnToken = _readBytes32(messageBody, BODY_BURN_TOKEN_INDEX);
        uint256 _amount = uint256(_readBytes32(messageBody, BODY_AMOUNT_INDEX));
        uint256 _fee = uint256(_readBytes32(messageBody, BODY_FEE_EXECUTED_INDEX));

        MockCctpV2TokenMinter(localMinter).mint(
            remoteDomain, _burnToken, _mintRecipient, feeRecipient, _amount - _fee, _fee
        );

        return true;
    }

    function setSourceDomain(uint32 _sourceDomain) external {
        sourceDomain = _sourceDomain;
    }

    function setMinFeeRate(uint256 _feeRate) external {
        minFee = _feeRate;
    }

    function _calcMinFeeAmount(uint256 _amount) internal view returns (uint256) {
        uint256 _minFeeAmount = _amount * minFee / 10_000_000;
        return _minFeeAmount == 0 ? 1 : _minFeeAmount;
    }

    function _readBytes32(bytes memory data, uint256 index) private pure returns (bytes32 result) {
        if (data.length < index + 32) {
            revert InvalidMessageBody();
        }
        assembly {
            result := mload(add(add(data, 0x20), index))
        }
    }
}
