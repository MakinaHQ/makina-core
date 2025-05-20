// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {MerkleProofs} from "./MerkleProofs.sol";
import {ICaliber} from "../../src/interfaces/ICaliber.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockBorrowModule} from "../mocks/MockBorrowModule.sol";
import {MockSupplyModule} from "../mocks/MockSupplyModule.sol";
import {MockPool} from "../mocks/MockPool.sol";
import {MockFlashLoanModule} from "../mocks/MockFlashLoanModule.sol";

library WeirollUtils {
    bytes32 internal constant ACCOUNTING_OUTPUT_STATE_END_OF_ARGS = bytes32(type(uint256).max);

    function buildCommand(bytes4 _selector, bytes1 _flags, bytes6 _input, bytes1 _output, address _target)
        internal
        pure
        returns (bytes32)
    {
        uint256 selector = uint256(bytes32(_selector));
        uint256 flags = uint256(uint8(_flags)) << 216;
        uint256 input = uint256(uint48(_input)) << 168;
        uint256 output = uint256(uint8(_output)) << 160;
        uint256 target = uint256(uint160(_target));

        return bytes32(selector ^ flags ^ input ^ output ^ target);
    }

    function _build4626DepositInstruction(address _caliber, uint256 _posId, address _vault, uint256 _assets)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = IERC4626(_vault).asset();

        bytes32[] memory commands = new bytes32[](2);
        // "0x095ea7b3010001ffffffffff" + IERC4626(_vault).asset()
        commands[0] = buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            IERC4626(_vault).asset()
        );
        // "0x6e553f65010102ffffffffff" + _vault
        commands[1] = buildCommand(
            IERC4626.deposit.selector,
            0x01, // call
            0x0102ffffffff, // 2 inputs at indices 1 and 2 of state
            0xff, // ignore result
            _vault
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(_vault);
        state[1] = abi.encode(_assets);
        state[2] = abi.encode(_caliber);

        bytes32[] memory merkleProof = MerkleProofs._getDeposit4626InstrProof();

        uint128 stateBitmap = 0xa0000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId,
            false,
            ICaliber.InstructionType.MANAGEMENT,
            affectedTokens,
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _build4626RedeemInstruction(address _caliber, uint256 _posId, address _vault, uint256 _shares)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = IERC4626(_vault).asset();

        bytes32[] memory commands = new bytes32[](1);
        // "0xba08765201000102ffffffff" + _vault
        commands[0] = buildCommand(
            IERC4626.redeem.selector,
            0x01, // call
            0x000102ffffff, // 3 inputs at indices 0, 1 and 2 of state
            0xff, // ignore result
            _vault
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(_shares);
        state[1] = abi.encode(_caliber);
        state[2] = abi.encode(_caliber);

        uint128 stateBitmap = 0x60000000000000000000000000000000;

        bytes32[] memory merkleProof = MerkleProofs._getRedeem4626InstrProof();

        return ICaliber.Instruction(
            _posId,
            false,
            ICaliber.InstructionType.MANAGEMENT,
            affectedTokens,
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _build4626AccountingInstruction(address _caliber, uint256 _posId, address _vault)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = IERC4626(_vault).asset();

        bytes32[] memory commands = new bytes32[](3);
        // "0x38d52e0f02ffffffffffff00" + _vault
        commands[0] = buildCommand(
            IERC4626.asset.selector,
            0x02, // static call
            0xffffffffffff, // no input
            0x00, // store fixed size result at index 0 of state
            _vault
        );
        // "0x70a082310202ffffffffff02" + _vault
        commands[1] = buildCommand(
            IERC20.balanceOf.selector,
            0x02, // static call
            0x02ffffffffff, // 1 input at index 2 of state
            0x02, // store fixed size result at index 2 of state
            _vault
        );
        // "0x4cdad5060202ffffffffff00" + _vault
        commands[2] = buildCommand(
            IERC4626.previewRedeem.selector,
            0x02, // static call
            0x02ffffffffff, // 1 input at index 2 of state
            0x00, // store fixed size result at index 0 of state
            _vault
        );

        bytes[] memory state = new bytes[](3);
        state[1] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);
        state[2] = abi.encode(_caliber);

        uint128 stateBitmap = 0x20000000000000000000000000000000;

        bytes32[] memory merkleProof = MerkleProofs._getAccounting4626InstrProof();

        return ICaliber.Instruction(
            _posId,
            false,
            ICaliber.InstructionType.ACCOUNTING,
            affectedTokens,
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockSupplyModuleSupplyInstruction(uint256 _posId, address _supplyModule, uint256 _assets)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockSupplyModule(_supplyModule).asset();

        bytes32[] memory commands = new bytes32[](2);
        // "0x095ea7b3010001ffffffffff" + MockSupplyModule(_supplyModule).asset()
        commands[0] = buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            MockSupplyModule(_supplyModule).asset()
        );
        // "0x354030230101ffffffffffff" + _supplyModule
        commands[1] = buildCommand(
            MockSupplyModule.supply.selector,
            0x01, // call
            0x01ffffffffff, // 1 input at indices 1 of state
            0xff, // ignore result
            _supplyModule
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(_supplyModule);
        state[1] = abi.encode(_assets);

        bytes32[] memory merkleProof = MerkleProofs._getSupplyMockSupplyModuleInstrProof();

        uint128 stateBitmap = 0x80000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId,
            false,
            ICaliber.InstructionType.MANAGEMENT,
            affectedTokens,
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockSupplyModuleWithdrawInstruction(uint256 _posId, address _supplyModule, uint256 _assets)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockSupplyModule(_supplyModule).asset();

        bytes32[] memory commands = new bytes32[](1);
        // "0x2e1a7d4d0100ffffffffffff" + _supplyModule
        commands[0] = buildCommand(
            MockSupplyModule.withdraw.selector,
            0x01, // call
            0x00ffffffffff, // 1 input at indices 0 of state
            0xff, // ignore result
            _supplyModule
        );

        bytes[] memory state = new bytes[](1);
        state[0] = abi.encode(_assets);

        bytes32[] memory merkleProof = MerkleProofs._getWithdrawMockSupplyModuleInstrProof();

        uint128 stateBitmap = 0x00000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId,
            false,
            ICaliber.InstructionType.MANAGEMENT,
            affectedTokens,
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockSupplyModuleAccountingInstruction(address _caliber, uint256 _posId, address _supplyModule)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockSupplyModule(_supplyModule).asset();

        bytes32[] memory commands = new bytes32[](1);
        // "0x1aefb1070200ffffffffff00" + _supplyModule
        commands[0] = buildCommand(
            MockSupplyModule.collateralOf.selector,
            0x02, // static call
            0x00ffffffffff, // 1 input at index 0 of state
            0x00, // store fixed size result at index 0 of state
            _supplyModule
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(_caliber);
        state[1] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);

        bytes32[] memory merkleProof = MerkleProofs._getAccountingMockSupplyModuleInstrProof();

        uint128 stateBitmap = 0x80000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId,
            false,
            ICaliber.InstructionType.ACCOUNTING,
            affectedTokens,
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockBorrowModuleBorrowInstruction(uint256 _posId, address _borrowModule, uint256 _assets)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockBorrowModule(_borrowModule).asset();

        bytes32[] memory commands = new bytes32[](1);
        // "0xc5ebeaec0100ffffffffffff" + _borrowModule
        commands[0] = buildCommand(
            MockBorrowModule.borrow.selector,
            0x01, // call
            0x00ffffffffff, // 1 input at indices 0 of state
            0xff, // ignore result
            _borrowModule
        );

        bytes[] memory state = new bytes[](1);
        state[0] = abi.encode(_assets);

        bytes32[] memory merkleProof = MerkleProofs._getBorrowMockBorrowModuleInstrProof();

        uint128 stateBitmap = 0x00000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId, true, ICaliber.InstructionType.MANAGEMENT, affectedTokens, commands, state, stateBitmap, merkleProof
        );
    }

    function _buildMockBorrowModuleRepayInstruction(uint256 _posId, address _borrowModule, uint256 _assets)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockBorrowModule(_borrowModule).asset();

        bytes32[] memory commands = new bytes32[](2);
        // "0x095ea7b3010001ffffffffff" + MockBorrowModule(_borrowModule).asset()
        commands[0] = buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            MockBorrowModule(_borrowModule).asset()
        );
        // "0x371fd8e60101ffffffffffff" + _borrowModule
        commands[1] = buildCommand(
            MockBorrowModule.repay.selector,
            0x01, // call
            0x01ffffffffff, // 1 input at indices 1 of state
            0xff, // ignore result
            _borrowModule
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(_borrowModule);
        state[1] = abi.encode(_assets);

        bytes32[] memory merkleProof = MerkleProofs._getRepayMockBorrowModuleInstrProof();

        uint128 stateBitmap = 0x80000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId, true, ICaliber.InstructionType.MANAGEMENT, affectedTokens, commands, state, stateBitmap, merkleProof
        );
    }

    function _buildMockBorrowModuleAccountingInstruction(address _caliber, uint256 _posId, address _borrowModule)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockBorrowModule(_borrowModule).asset();

        bytes32[] memory commands = new bytes32[](1);
        // "0xd283e75f0200ffffffffff00" + _borrowModule
        commands[0] = buildCommand(
            MockBorrowModule.debtOf.selector,
            0x02, // static call
            0x00ffffffffff, // 1 input at index 0 of state
            0x00, // store fixed size result at index 0 of state
            _borrowModule
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(_caliber);
        state[1] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);

        bytes32[] memory merkleProof = MerkleProofs._getAccountingMockBorrowModuleInstrProof();

        uint128 stateBitmap = 0x80000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId, true, ICaliber.InstructionType.ACCOUNTING, affectedTokens, commands, state, stateBitmap, merkleProof
        );
    }

    function _buildMockPoolAddLiquidityInstruction(uint256 _posId, address _pool, uint256 _assets0, uint256 _assets1)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](2);
        affectedTokens[0] = MockPool(_pool).token0();
        affectedTokens[1] = MockPool(_pool).token1();

        bytes32[] memory commands = new bytes32[](3);
        // "0x095ea7b3010001ffffffffff" + MockPool(_pool).token0()
        commands[0] = buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            MockPool(_pool).token0()
        );
        // "0x095ea7b3010002ffffffffff" + MockPool(_pool).token1()
        commands[1] = buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0002ffffffff, // 2 inputs at indices 0 and 2 of state
            0xff, // ignore result
            MockPool(_pool).token1()
        );
        // "0x9cd441da010102ffffffffff" + _pool
        commands[2] = buildCommand(
            MockPool.addLiquidity.selector,
            0x01, // call
            0x0102ffffffff, // 2 inputs at indices 1 and 2 of state
            0xff, // ignore result
            _pool
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(_pool);
        state[1] = abi.encode(_assets0);
        state[2] = abi.encode(_assets1);

        bytes32[] memory merkleProof = MerkleProofs._getAddLiquidityMockPoolInstrProof();

        uint128 stateBitmap = 0x80000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId,
            false,
            ICaliber.InstructionType.MANAGEMENT,
            affectedTokens,
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockPoolAddLiquidityOneSideInstruction(uint256 _posId, address _pool, uint256 _assets, bool _side)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address token = _side ? MockPool(_pool).token1() : MockPool(_pool).token0();

        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = token;

        bytes32[] memory commands = new bytes32[](2);
        // "0x095ea7b3010001ffffffffff" + token
        commands[0] = buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            token
        );
        // "0x8e022364010102ffffffffff" + _pool
        commands[1] = buildCommand(
            MockPool.addLiquidityOneSide.selector,
            0x01, // call
            0x0102ffffffff, // 2 inputs at indices 1 and 2 of state
            0xff, // ignore result
            _pool
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(_pool);
        state[1] = abi.encode(_assets);
        state[2] = abi.encode(token);

        bytes32[] memory merkleProof = _side
            ? MerkleProofs._getAddLiquidityOneSide1MockPoolInstrProof()
            : MerkleProofs._getAddLiquidityOneSide0MockPoolInstrProof();

        uint128 stateBitmap = 0xa0000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId,
            false,
            ICaliber.InstructionType.MANAGEMENT,
            affectedTokens,
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockPoolRemoveLiquidityOneSideInstruction(
        uint256 _posId,
        address _pool,
        uint256 _lpTokens,
        bool _side
    ) internal view returns (ICaliber.Instruction memory) {
        address token = _side ? MockPool(_pool).token1() : MockPool(_pool).token0();
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = token;

        bytes32[] memory commands = new bytes32[](1);
        // "0xdf7aebb9010001ffffffffff" + _pool
        commands[0] = buildCommand(
            MockPool.removeLiquidityOneSide.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            _pool
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(_lpTokens);
        state[1] = abi.encode(token);

        bytes32[] memory merkleProof = _side
            ? MerkleProofs._getRemoveLiquidityOneSide1MockPoolInstrProof()
            : MerkleProofs._getRemoveLiquidityOneSide0MockPoolInstrProof();

        uint128 stateBitmap = 0x40000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId,
            false,
            ICaliber.InstructionType.MANAGEMENT,
            affectedTokens,
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    /// @dev Builds a mock pool accounting instruction which considers one-sided liquidity removal from a pool (only token1)
    function _buildMockPoolAccountingInstruction(address _caliber, uint256 _posId, address _pool, bool _side)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address token = _side ? MockPool(_pool).token1() : MockPool(_pool).token0();
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = token;

        bytes32[] memory commands = new bytes32[](2);
        // "0x70a082310202ffffffffff02" + _pool
        commands[0] = buildCommand(
            IERC20.balanceOf.selector,
            0x02, // static call
            0x02ffffffffff, // 1 input at index 2 of state
            0x02, // store fixed size result at index 2 of state
            _pool
        );
        // "0xeeb47144020200ffffffff00" + _pool
        commands[1] = buildCommand(
            MockPool.previewRemoveLiquidityOneSide.selector,
            0x02, // call
            0x0200ffffffff, // 2 inputs at indices 2 and 0 of state
            0x00, // store fixed size result at index 0 of state
            _pool
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(token);
        state[1] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);
        state[2] = abi.encode(_caliber);

        bytes32[] memory merkleProof =
            _side ? MerkleProofs._getAccounting1MockPoolInstrProof() : MerkleProofs._getAccounting0MockPoolInstrProof();

        uint128 stateBitmap = 0xa0000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId,
            false,
            ICaliber.InstructionType.ACCOUNTING,
            affectedTokens,
            commands,
            state,
            stateBitmap,
            merkleProof
        );
    }

    function _buildMockRewardTokenHarvestInstruction(address _caliber, address _mockRewardToken, uint256 _harvestAmount)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        bytes32[] memory commands = new bytes32[](1);
        // "0x40c10f19010001ffffffffff" + _mockRewardToken
        commands[0] = buildCommand(
            MockERC20.mint.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            _mockRewardToken
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(_caliber);
        state[1] = abi.encode(_harvestAmount);

        bytes32[] memory merkleProof = MerkleProofs._getHarvestMockBaseTokenInstrProof();

        uint128 stateBitmap = 0x80000000000000000000000000000000;

        return ICaliber.Instruction(
            0, false, ICaliber.InstructionType.HARVEST, new address[](0), commands, state, stateBitmap, merkleProof
        );
    }

    function _buildMockFlashLoanModuleDummyLoopInstruction(
        uint256 _posId,
        address _flashLoanModule,
        address _token,
        uint256 _amount,
        ICaliber.Instruction memory _manageFlashloanInstruction
    ) internal view returns (ICaliber.Instruction memory) {
        bytes32[] memory commands = new bytes32[](1);
        // "0x76ab19f141820001ffffffff" + _flashLoanModule
        commands[0] = buildCommand(
            MockFlashLoanModule.flashLoan.selector,
            0x01, // call with extended flag
            0x820001ffffff, // 3 inputs : variable-length at index 2, fixed at indices 0 and 1 of state
            0xff, // ignore result
            _flashLoanModule
        );

        bytes[] memory state = new bytes[](3);
        state[0] = abi.encode(_token);
        state[1] = abi.encode(_amount);
        state[2] = abi.encode(
            _manageFlashloanInstruction.positionId,
            _manageFlashloanInstruction.isDebt,
            _manageFlashloanInstruction.instructionType,
            _manageFlashloanInstruction.affectedTokens,
            _manageFlashloanInstruction.commands,
            _manageFlashloanInstruction.state,
            _manageFlashloanInstruction.stateBitmap,
            _manageFlashloanInstruction.merkleProof
        );

        bytes32[] memory merkleProof = MerkleProofs._getDummyLoopMockFlashLoanModuleInstrProof();

        return ICaliber.Instruction(
            _posId, false, ICaliber.InstructionType.MANAGEMENT, new address[](0), commands, state, 0, merkleProof
        );
    }

    function _buildMockFlashLoanModuleDummyAccountingInstruction(uint256 _posId)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        bytes[] memory state = new bytes[](1);
        state[0] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);

        bytes32[] memory merkleProof = MerkleProofs._getAccountingMockFlashLoanModuleInstrProof();

        return ICaliber.Instruction(
            _posId,
            false,
            ICaliber.InstructionType.ACCOUNTING,
            new address[](0),
            new bytes32[](0),
            state,
            0,
            merkleProof
        );
    }

    function _buildManageFlashLoanDummyInstruction(uint256 _posId)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        bytes32[] memory merkleProof = MerkleProofs._getManageFlashLoanDummyInstrProof();

        return ICaliber.Instruction(
            _posId,
            false,
            ICaliber.InstructionType.FLASHLOAN_MANAGEMENT,
            new address[](0),
            new bytes32[](0),
            new bytes[](0),
            0,
            merkleProof
        );
    }
}
