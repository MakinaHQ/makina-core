// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {ExecutorOptions} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/libs/ExecutorOptions.sol";

/// @title LzOptionsBuilder
/// @dev Library for building and encoding various LayerZero V2 message options.
///      Forked and simplified from layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol
library LzOptionsBuilder {
    using SafeCast for uint256;

    uint16 internal constant TYPE_3 = 3;

    function newOptions() internal pure returns (bytes memory) {
        return abi.encodePacked(TYPE_3);
    }

    function addExecutorLzReceiveOption(bytes memory _options, uint128 _gas) internal pure returns (bytes memory) {
        return addExecutorOption(_options, ExecutorOptions.OPTION_TYPE_LZRECEIVE, abi.encodePacked(_gas));
    }

    function addExecutorLzComposeOption(bytes memory _options, uint16 _index, uint128 _gas)
        internal
        pure
        returns (bytes memory)
    {
        return addExecutorOption(_options, ExecutorOptions.OPTION_TYPE_LZCOMPOSE, abi.encodePacked(_index, _gas));
    }

    function addExecutorOption(bytes memory _options, uint8 _optionType, bytes memory _option)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _options,
            ExecutorOptions.WORKER_ID,
            _option.length.toUint16() + 1, // +1 for optionType
            _optionType,
            _option
        );
    }
}
