// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {OFTMock} from "@layerzerolabs/oft-evm/test/mocks/OFTMock.sol";
import {
    SendParam, MessagingFee, MessagingReceipt, OFTReceipt
} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

/// @dev MockOFT contract for testing use only
contract MockOFT is OFTMock {
    event SentParams(
        uint32 dstEid, bytes32 to, uint256 amountLD, uint256 minAmountLD, bytes encodedMessage, bytes extraoptions
    );

    constructor(string memory _name, string memory _symbol, address _lzEndpoint, address _delegate)
        OFTMock(_name, _symbol, _lzEndpoint, _delegate)
    {}

    bool public faultyModeSend;
    bool public faultyModeReceive;

    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
        override
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        emit SentParams(
            _sendParam.dstEid,
            _sendParam.to,
            _sendParam.amountLD,
            _sendParam.minAmountLD,
            _sendParam.composeMsg,
            _sendParam.extraOptions
        );

        return _send(_sendParam, _fee, _refundAddress);
    }

    function _debitView(uint256 _amountLD, uint256 _minAmountLD, uint32 /*_dstEid*/ )
        internal
        view
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        uint256 _amountSentLD = _removeDust(_amountLD);

        if (faultyModeSend) {
            amountSentLD = _amountSentLD / 2;
        } else {
            amountSentLD = _amountSentLD;
        }

        if (faultyModeReceive) {
            amountReceivedLD = _amountSentLD / 2;
        } else {
            amountReceivedLD = _amountSentLD;

            if (amountReceivedLD < _minAmountLD) {
                revert SlippageExceeded(amountReceivedLD, _minAmountLD);
            }
        }
    }

    function setFaultyModeSend(bool _faultyMode) public {
        faultyModeSend = _faultyMode;
    }

    function setFaultyModeReceive(bool _faultyMode) public {
        faultyModeReceive = _faultyMode;
    }
}
