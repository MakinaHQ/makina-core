// SPDX-License-Identifier: LZBL-1.2
pragma solidity 0.8.28;

import {EndpointV2Mock} from "@layerzerolabs/test-evm/contracts/mocks/EndpointV2Mock.sol";

contract MockLayerZeroEndpointV2 is EndpointV2Mock {
    constructor(uint32 _eid, address _owner) EndpointV2Mock(_eid, _owner) {}
}