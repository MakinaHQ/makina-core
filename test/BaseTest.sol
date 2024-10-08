// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "./Base.sol";

abstract contract BaseTest is Base {
    /// @dev set MAINNET_RPC_URL in .env to run mainnet tests
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        vm.selectFork(vm.createFork(MAINNET_RPC_URL));

        _testSetupBefore();
        _coreSetup();
        _testSetupAfter();

        _setUp();
    }

    /// @dev Can be overriden to provide additional configuration
    function _setUp() public virtual {}

    function _testSetupBefore() public {}

    function _testSetupAfter() public {}
}
