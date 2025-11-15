// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {Packet} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ISendLib.sol";
import {IMessageLib, MessageLibType} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLib.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract MockLzSendLib is ERC165 {
    uint256 public nativeFee;
    uint256 public lzReceiveFee;
    uint256 public lzComposeFee;

    function quote(Packet calldata, bytes calldata, bool) external view returns (MessagingFee memory) {
        return MessagingFee(nativeFee + lzReceiveFee + lzComposeFee, 0);
    }

    function send(Packet calldata, bytes memory, bool)
        external
        view
        returns (MessagingFee memory, bytes memory, bytes memory)
    {
        return (MessagingFee(nativeFee + lzReceiveFee + lzComposeFee, 0), "", "");
    }

    function setNativeFee(uint256 _fee) external {
        nativeFee = _fee;
    }

    function setLzReceiveFee(uint256 _fee) external {
        lzReceiveFee = _fee;
    }

    function setLzComposeFee(uint256 _fee) external {
        lzComposeFee = _fee;
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
