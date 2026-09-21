// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {CreateXUtils} from "script/deployments/utils/CreateXUtils.sol";

import {Constants} from "../utils/Constants.sol";

contract CreateXUtilsHarness is CreateXUtils {
    function formatSalt(bytes32 salt, address deployer) external pure returns (bytes32) {
        return _formatSalt(salt, deployer);
    }

    function computeCreateXAddress(bytes calldata bytecode, bytes32 salt, address deployer)
        external
        view
        returns (address)
    {
        return _computeCreateXAddress(bytecode, salt, deployer);
    }

    function deployCodeCreateX(bytes calldata bytecode, bytes32 salt, address deployer) external returns (address) {
        return _deployCodeCreateX(bytecode, salt, deployer);
    }
}

contract Dummy {}

contract CreateXUtils_Test is Test, Constants {
    bytes32 internal constant TEST_SALT_DOMAIN = keccak256("makina.salt.test");

    CreateXUtilsHarness public harness;

    function setUp() public {
        harness = new CreateXUtilsHarness();
    }

    /// @dev Fork tests need the live CreateX factory. The harness is redeployed on the fork, as the one from `setUp`
    ///      only exists on the local chain.
    function _forkMainnet() internal {
        vm.createSelectFork({urlOrAlias: getChain(ETHEREUM_CHAIN_ID).chainAlias});
        harness = new CreateXUtilsHarness();
    }

    function test_FormatSalt_BindsSaltToDeployer() public {
        address deployer = makeAddr("deployer");
        bytes32 salt = harness.formatSalt(TEST_SALT_DOMAIN, deployer);

        // CreateX only guards the salt as sender-bound when its first 20 bytes are the sender
        assertEq(address(bytes20(salt)), deployer);
        // and the 21st byte is the redeploy protection flag, left unset to allow the same address on every chain
        assertEq(salt[20], bytes1(0));
    }

    function test_RevertWhen_FormatSaltWithZeroDeployer() public {
        // A zero-prefixed salt is guarded by CreateX as permissionless, so anyone could squat the address
        vm.expectRevert(bytes("CreateXUtils: zero deployer"));
        harness.formatSalt(TEST_SALT_DOMAIN, address(0));
    }

    function testFork_ComputeCreateXAddress_MatchesCreate2Deployment() public {
        _forkMainnet();

        // The harness is the CreateX caller, so the salt is bound to its address
        address deployer = address(harness);
        bytes memory bytecode = type(Dummy).creationCode;

        address expected = harness.computeCreateXAddress(bytecode, 0, deployer);
        assertEq(expected.code.length, 0);

        assertEq(harness.deployCodeCreateX(bytecode, 0, deployer), expected);
        assertGt(expected.code.length, 0);
    }

    function testFork_ComputeCreateXAddress_MatchesCreate3Deployment() public {
        _forkMainnet();

        address deployer = address(harness);
        bytes memory bytecode = type(Dummy).creationCode;

        address expected = harness.computeCreateXAddress(bytecode, TEST_SALT_DOMAIN, deployer);
        assertEq(expected.code.length, 0);

        assertEq(harness.deployCodeCreateX(bytecode, TEST_SALT_DOMAIN, deployer), expected);
        assertGt(expected.code.length, 0);
    }

    function testFork_ComputeCreateXAddress_Create3IsIndependentOfBytecode() public {
        _forkMainnet();

        address deployer = address(harness);

        assertEq(
            harness.computeCreateXAddress(type(Dummy).creationCode, TEST_SALT_DOMAIN, deployer),
            harness.computeCreateXAddress(type(CreateXUtilsHarness).creationCode, TEST_SALT_DOMAIN, deployer)
        );
    }
}
