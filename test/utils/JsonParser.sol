// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Vm} from "forge-std/Vm.sol";

import {IBridgeAdapterFactory} from "../../src/interfaces/IBridgeAdapterFactory.sol";
import {ICaliber} from "../../src/interfaces/ICaliber.sol";
import {IMachine} from "../../src/interfaces/IMachine.sol";
import {IMakinaGovernable} from "../../src/interfaces/IMakinaGovernable.sol";
import {IPreDepositVault} from "../../src/interfaces/IPreDepositVault.sol";

abstract contract JsonParser {
    struct PriceFeedRoute {
        address token;
        address feed1;
        uint256 stalenessThreshold1;
        address feed2;
        uint256 stalenessThreshold2;
    }

    struct TokenToRegister {
        address localToken;
        uint256 foreignEvmChainId;
        address foreignToken;
    }

    struct SwapperData {
        uint16 swapperId;
        address approvalTarget;
        address executionTarget;
    }

    struct BridgeData {
        uint16 bridgeId;
        address approvalTarget;
        address executionTarget;
        address receiveSource;
    }

    struct AMRoleGrant {
        uint64 roleId;
        address account;
        uint32 executionDelay;
    }

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function parsePriceFeedRoutes(string memory inputJson, string memory key)
        internal
        view
        returns (PriceFeedRoute[] memory)
    {
        uint256 len = _getArrayLength(inputJson, key);

        PriceFeedRoute[] memory priceFeedRoutes = new PriceFeedRoute[](len);
        for (uint256 i; i < len; ++i) {
            string memory base = _getArrayElementBasePath(key, i);
            priceFeedRoutes[i] = PriceFeedRoute({
                token: vm.parseJsonAddress(inputJson, string.concat(base, ".token")),
                feed1: vm.parseJsonAddress(inputJson, string.concat(base, ".feed1")),
                stalenessThreshold1: vm.parseJsonUint(inputJson, string.concat(base, ".stalenessThreshold1")),
                feed2: vm.parseJsonAddress(inputJson, string.concat(base, ".feed2")),
                stalenessThreshold2: vm.parseJsonUint(inputJson, string.concat(base, ".stalenessThreshold2"))
            });
        }

        return priceFeedRoutes;
    }

    function parseTokensToRegister(string memory inputJson, string memory key)
        internal
        view
        returns (TokenToRegister[] memory)
    {
        uint256 len = _getArrayLength(inputJson, key);

        TokenToRegister[] memory tokensToRegister = new TokenToRegister[](len);
        for (uint256 i; i < len; ++i) {
            string memory base = _getArrayElementBasePath(key, i);
            tokensToRegister[i] = TokenToRegister({
                localToken: vm.parseJsonAddress(inputJson, string.concat(base, ".localToken")),
                foreignEvmChainId: vm.parseJsonUint(inputJson, string.concat(base, ".foreignEvmChainId")),
                foreignToken: vm.parseJsonAddress(inputJson, string.concat(base, ".foreignToken"))
            });
        }

        return tokensToRegister;
    }

    function parseSwappersData(string memory inputJson, string memory key)
        internal
        view
        returns (SwapperData[] memory)
    {
        uint256 len = _getArrayLength(inputJson, key);

        SwapperData[] memory swappersData = new SwapperData[](len);
        for (uint256 i; i < len; ++i) {
            string memory base = _getArrayElementBasePath(key, i);
            swappersData[i] = SwapperData({
                swapperId: uint16(vm.parseJsonUint(inputJson, string.concat(base, ".swapperId"))),
                approvalTarget: vm.parseJsonAddress(inputJson, string.concat(base, ".approvalTarget")),
                executionTarget: vm.parseJsonAddress(inputJson, string.concat(base, ".executionTarget"))
            });
        }

        return swappersData;
    }

    function parseBridgesData(string memory inputJson, string memory key) internal view returns (BridgeData[] memory) {
        uint256 len = _getArrayLength(inputJson, key);

        BridgeData[] memory bridgesData = new BridgeData[](len);
        for (uint256 i; i < len; ++i) {
            string memory base = _getArrayElementBasePath(key, i);
            bridgesData[i] = BridgeData({
                bridgeId: uint16(vm.parseJsonUint(inputJson, string.concat(base, ".bridgeId"))),
                approvalTarget: vm.parseJsonAddress(inputJson, string.concat(base, ".approvalTarget")),
                executionTarget: vm.parseJsonAddress(inputJson, string.concat(base, ".executionTarget")),
                receiveSource: vm.parseJsonAddress(inputJson, string.concat(base, ".receiveSource"))
            });
        }

        return bridgesData;
    }

    function parseAMRoleGrants(string memory inputJson, string memory key)
        internal
        view
        returns (AMRoleGrant[] memory)
    {
        uint256 len = _getArrayLength(inputJson, key);

        AMRoleGrant[] memory roleGrants = new AMRoleGrant[](len);
        for (uint256 i; i < len; ++i) {
            string memory base = _getArrayElementBasePath(key, i);
            roleGrants[i] = AMRoleGrant({
                roleId: uint64(vm.parseJsonUint(inputJson, string.concat(base, ".roleId"))),
                account: vm.parseJsonAddress(inputJson, string.concat(base, ".account")),
                executionDelay: uint32(vm.parseJsonUint(inputJson, string.concat(base, ".executionDelay")))
            });
        }

        return roleGrants;
    }

    function parseMachineInitParams(string memory inputJson, string memory key)
        internal
        pure
        returns (IMachine.MachineInitParams memory)
    {
        return IMachine.MachineInitParams({
            initialDepositor: vm.parseJsonAddress(inputJson, string.concat(key, ".initialDepositor")),
            initialRedeemer: vm.parseJsonAddress(inputJson, string.concat(key, ".initialRedeemer")),
            initialFeeManager: vm.parseJsonAddress(inputJson, string.concat(key, ".initialFeeManager")),
            initialCaliberStaleThreshold: vm.parseJsonUint(
                inputJson, string.concat(key, ".initialCaliberStaleThreshold")
            ),
            initialMaxFixedFeeAccrualRate: vm.parseJsonUint(
                inputJson, string.concat(key, ".initialMaxFixedFeeAccrualRate")
            ),
            initialMaxPerfFeeAccrualRate: vm.parseJsonUint(
                inputJson, string.concat(key, ".initialMaxPerfFeeAccrualRate")
            ),
            initialFeeMintCooldown: vm.parseJsonUint(inputJson, string.concat(key, ".initialFeeMintCooldown")),
            initialShareLimit: vm.parseJsonUint(inputJson, string.concat(key, ".initialShareLimit")),
            initialMaxSharePriceChangeRate: vm.parseJsonUint(
                inputJson, string.concat(key, ".initialMaxSharePriceChangeRate")
            )
        });
    }

    function parsePreDepositVaultInitParams(string memory inputJson, string memory key)
        internal
        pure
        returns (IPreDepositVault.PreDepositVaultInitParams memory)
    {
        return IPreDepositVault.PreDepositVaultInitParams({
            initialShareLimit: vm.parseJsonUint(inputJson, string.concat(key, ".initialShareLimit")),
            initialWhitelistMode: vm.parseJsonBool(inputJson, string.concat(key, ".initialWhitelistMode")),
            initialRiskManager: vm.parseJsonAddress(inputJson, string.concat(key, ".initialRiskManager")),
            initialAuthority: vm.parseJsonAddress(inputJson, string.concat(key, ".initialAuthority"))
        });
    }

    function parseCaliberInitParams(string memory inputJson, string memory key)
        internal
        pure
        returns (ICaliber.CaliberInitParams memory)
    {
        return ICaliber.CaliberInitParams({
            initialPositionStaleThreshold: vm.parseJsonUint(
                inputJson, string.concat(key, ".initialPositionStaleThreshold")
            ),
            initialAllowedInstrRoot: vm.parseJsonBytes32(inputJson, string.concat(key, ".initialAllowedInstrRoot")),
            initialTimelockDuration: vm.parseJsonUint(inputJson, string.concat(key, ".initialTimelockDuration")),
            initialMaxPositionIncreaseLossBps: vm.parseJsonUint(
                inputJson, string.concat(key, ".initialMaxPositionIncreaseLossBps")
            ),
            initialMaxPositionDecreaseLossBps: vm.parseJsonUint(
                inputJson, string.concat(key, ".initialMaxPositionDecreaseLossBps")
            ),
            initialMaxSwapLossBps: vm.parseJsonUint(inputJson, string.concat(key, ".initialMaxSwapLossBps")),
            initialCooldownDuration: vm.parseJsonUint(inputJson, string.concat(key, ".initialCooldownDuration")),
            initialBaseTokens: vm.parseJsonAddressArray(inputJson, string.concat(key, ".initialBaseTokens"))
        });
    }

    function parseMakinaGovernableInitParams(string memory inputJson, string memory key)
        internal
        pure
        returns (IMakinaGovernable.MakinaGovernableInitParams memory)
    {
        return IMakinaGovernable.MakinaGovernableInitParams({
            initialMechanic: vm.parseJsonAddress(inputJson, string.concat(key, ".initialMechanic")),
            initialSecurityCouncil: vm.parseJsonAddress(inputJson, string.concat(key, ".initialSecurityCouncil")),
            initialRiskManager: vm.parseJsonAddress(inputJson, string.concat(key, ".initialRiskManager")),
            initialRiskManagerTimelock: vm.parseJsonAddress(
                inputJson, string.concat(key, ".initialRiskManagerTimelock")
            ),
            initialAuthority: vm.parseJsonAddress(inputJson, string.concat(key, ".initialAuthority")),
            initialRestrictedAccountingMode: vm.parseJsonBool(
                inputJson, string.concat(key, ".initialRestrictedAccountingMode")
            ),
            initialAccountingAgents: vm.parseJsonAddressArray(inputJson, string.concat(key, ".initialAccountingAgents"))
        });
    }

    function parseBridgeAdaptersInitParams(string memory inputJson, string memory key)
        internal
        view
        returns (IBridgeAdapterFactory.BridgeAdapterInitParams[] memory)
    {
        uint256 len = _getArrayLength(inputJson, key);

        IBridgeAdapterFactory.BridgeAdapterInitParams[] memory initParams =
            new IBridgeAdapterFactory.BridgeAdapterInitParams[](len);
        for (uint256 i; i < len; ++i) {
            string memory base = _getArrayElementBasePath(key, i);
            initParams[i] = IBridgeAdapterFactory.BridgeAdapterInitParams({
                bridgeId: uint16(vm.parseJsonUint(inputJson, string.concat(base, ".bridgeId"))),
                initData: vm.parseJsonBytes(inputJson, string.concat(base, ".initData")),
                initialMaxBridgeLossBps: vm.parseJsonUint(inputJson, string.concat(base, ".initialMaxBridgeLossBps"))
            });
        }

        return initParams;
    }

    function _getArrayLength(string memory inputJson, string memory key) internal view returns (uint256) {
        uint256 len;
        while (vm.keyExistsJson(inputJson, string.concat(key, "[", vm.toString(len), "]"))) {
            ++len;
        }
        return len;
    }

    function _getArrayElementBasePath(string memory key, uint256 i) internal pure returns (string memory) {
        return string.concat(key, "[", vm.toString(i), "]");
    }
}
