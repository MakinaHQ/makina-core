// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {Packet} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ISendLib.sol";
import {IMessageLib, MessageLibType} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLib.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract MockLzSendLib is ERC165 {
    uint256 public verifyGas;
    uint256 public lzReceiveGas;
    uint256 public lzComposeGas;

    uint256 public gasPrice;

    function quote(Packet calldata, bytes calldata, bool) external view returns (MessagingFee memory) {
        return MessagingFee((verifyGas + lzReceiveGas + lzComposeGas) * gasPrice, 0);
    }

    function send(Packet calldata, bytes memory, bool)
        external
        view
        returns (MessagingFee memory, bytes memory, bytes memory)
    {
        return (MessagingFee((verifyGas + lzReceiveGas + lzComposeGas) * gasPrice, 0), "", "");
    }

    function setVerifyGas(uint256 _verifyGas) external {
        verifyGas = _verifyGas;
    }

    function setLzReceiveGas(uint256 _lzReceiveGas) external {
        lzReceiveGas = _lzReceiveGas;
    }

    function setLzComposeGas(uint256 _lzComposeGas) external {
        lzComposeGas = _lzComposeGas;
    }

    function setGasPrice(uint256 _gasPrice) public {
        gasPrice = _gasPrice;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IMessageLib).interfaceId || super.supportsInterface(interfaceId);
    }

    function messageLibType() external pure returns (MessageLibType) {
        return MessageLibType.SendAndReceive;
    }

    function isSupportedEid(uint32) external pure returns (bool) {
        return true;
    }

    receive() external payable {}
}
