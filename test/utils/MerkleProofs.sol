// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";
import {Vm} from "forge-std/Vm.sol";

library MerkleProofs {
    using stdJson for string;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _getMerkleData() internal view returns (string memory) {
        return vm.readFile(string.concat(vm.projectRoot(), "/script/merkle/merkleTreeData.json"));
    }

    function _getAllowedInstrMerkleRoot() internal view returns (bytes32) {
        return _getMerkleData().readBytes32(".root");
    }

    function _getDeposit4626InstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofDepositMock4626");
    }

    function _getRedeem4626InstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofRedeemMock4626");
    }

    function _getAccounting4626InstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccountingMock4626");
    }

    function _getSupplyMockSupplyModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofSupplyMockSupplyModule");
    }

    function _getWithdrawMockSupplyModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofWithdrawMockSupplyModule");
    }

    function _getAccountingMockSupplyModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccountingMockSupplyModule");
    }

    function _getBorrowMockBorrowModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofBorrowMockBorrowModule");
    }

    function _getRepayMockBorrowModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofRepayMockBorrowModule");
    }

    function _getAccountingMockBorrowModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccountingMockBorrowModule");
    }

    function _getAddLiquidityMockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAddLiquidityMockPool");
    }

    function _getAddLiquidityOneSide0MockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAddLiquidityOneSide0MockPool");
    }

    function _getAddLiquidityOneSide1MockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAddLiquidityOneSide1MockPool");
    }

    function _getRemoveLiquidityOneSide0MockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofRemoveLiquidityOneSide0MockPool");
    }

    function _getRemoveLiquidityOneSide1MockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofRemoveLiquidityOneSide1MockPool");
    }

    function _getAccounting0MockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccounting0MockPool");
    }

    function _getAccounting1MockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccounting1MockPool");
    }

    function _getHarvestMockBaseTokenInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofHarvestMockBaseToken");
    }
}
