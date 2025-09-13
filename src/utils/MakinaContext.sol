// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IMakinaContext} from "../interfaces/IMakinaContext.sol";

abstract contract MakinaContext is IMakinaContext {
    /// @inheritdoc IMakinaContext
    address public immutable override registry;

    constructor(address _registry) {
        registry = _registry;
    }
}
