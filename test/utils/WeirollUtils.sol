// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {MerkleProofs} from "./MerkleProofs.sol";
import {ICaliber} from "src/interfaces/ICaliber.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockPool} from "test/mocks/MockPool.sol";

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
            _posId, ICaliber.InstructionType.MANAGEMENT, affectedTokens, commands, state, stateBitmap, merkleProof
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
            _posId, ICaliber.InstructionType.MANAGEMENT, affectedTokens, commands, state, stateBitmap, merkleProof
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
            _posId, ICaliber.InstructionType.ACCOUNTING, affectedTokens, commands, state, stateBitmap, merkleProof
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
            _posId, ICaliber.InstructionType.MANAGEMENT, affectedTokens, commands, state, stateBitmap, merkleProof
        );
    }

    function _buildMockPoolAddLiquidityOneSide0Instruction(uint256 _posId, address _pool, uint256 _assets0)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address token0 = MockPool(_pool).token0();

        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = token0;

        bytes32[] memory commands = new bytes32[](2);
        // "0x095ea7b3010001ffffffffff" + token0
        commands[0] = buildCommand(
            IERC20.approve.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs at indices 0 and 1 of state
            0xff, // ignore result
            token0
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
        state[1] = abi.encode(_assets0);
        state[2] = abi.encode(token0);

        bytes32[] memory merkleProof = MerkleProofs._getAddLiquidityOneSide0MockPoolInstrProof();

        uint128 stateBitmap = 0xa0000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId, ICaliber.InstructionType.MANAGEMENT, affectedTokens, commands, state, stateBitmap, merkleProof
        );
    }

    function _buildMockPoolRemoveLiquidityOneSide1Instruction(uint256 _posId, address _pool, uint256 _lpTokens)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address token1 = MockPool(_pool).token1();
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = token1;

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
        state[1] = abi.encode(token1);

        bytes32[] memory merkleProof = MerkleProofs._getRemoveLiquidityOneSide1MockPoolInstrProof();

        uint128 stateBitmap = 0x40000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId, ICaliber.InstructionType.MANAGEMENT, affectedTokens, commands, state, stateBitmap, merkleProof
        );
    }

    /// @dev Builds a mock pool accounting instruction for removing liquidity one-sided from a pool (only token1)
    function _buildMockPoolAccountingInstruction(address _caliber, uint256 _posId, address _pool)
        internal
        view
        returns (ICaliber.Instruction memory)
    {
        address[] memory affectedTokens = new address[](1);
        affectedTokens[0] = MockPool(_pool).token1();

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
        state[0] = abi.encode(MockPool(_pool).token1());
        state[1] = abi.encode(ACCOUNTING_OUTPUT_STATE_END_OF_ARGS);
        state[2] = abi.encode(_caliber);

        bytes32[] memory merkleProof = MerkleProofs._getAccountingMockPoolInstrProof();

        uint128 stateBitmap = 0xa0000000000000000000000000000000;

        return ICaliber.Instruction(
            _posId, ICaliber.InstructionType.ACCOUNTING, affectedTokens, commands, state, stateBitmap, merkleProof
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
            0, ICaliber.InstructionType.HARVEST, new address[](0), commands, state, stateBitmap, merkleProof
        );
    }
}
