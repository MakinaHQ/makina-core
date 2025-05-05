## Makina Core Specifications

## Protocol

### Machine

The `Machine` contract is the central and user-facing component of the protocol. It handles deposits, redemptions and share price calculation.

#### Accounting Token

Each Machine manages a dedicated share token representing user ownership in its strategy. The Machine has exclusive minting and burning rights over this token.

#### Machine Share Token

Each machine controls a share token, which represent users shares in a given strategy. The machine has minting and burning rights on the token.

#### Share price calculation

The share price consists essentially in the ratio between share token supply and the last calculated total machine AUM. In order to mitigate donation attacks, the conversion includes a `shareTokenDecimalsOffset` value representing the decimal offset between the accounting token and the share token. By setting the ratio between virtual shares and virtual assets in the vault, the offset also determines the initial exchange rate.

#### Fees

After each total AUM computation, machines apply three types of fees by inflating the share supply:

- Management Fees
- Security Module Fees
- Performance Fees

Managment and Security Module fees will be calculated based on share supply, independently of performance. Performance fees, on the other hand, are based on both share supply and share price performance. Fee calculations are delegated to a `FeeManager` module, classified as a periphery contract and excluded from this repository’s scope.

#### Cross-chain Accounting

In order to compute a machine's total AUM, accounting data of each caliber needs to be aggregated. For spoke calibers, the protocol relies on [Wormhole Cross-Chain Queries](https://wormhole.com/products/queries). Each caliber mailbox (see [Caliber](#mailbox) section) exposes a view function returning the detailed AUM of the associated caliber. This data can be retrieved by the Wormhole CCQ network, signed, and then aggregated in the machine contract storage.

#### Cross-chain Transfers

To move funds between the Hub Chain and Spoke Chains, the protocol supports multiple liquidity bridging protocols through a modular bridge adapter system. At each stage of a bridge transfer, the involved funds are accounted for in the Machine’s AUM calculation.

#### Standard Operator Actions:

- Can store the last accounting data from spoke calibers.
- Can recompute and update the total AUM, and mint fees.
- Can initiate a transfer towards a Caliber.

### Pre-Deposit Vault

The `PreDepositVault` is used during pre-deposit campaigns to onboard users capital ahead of a `Machine` deployment. It is deployed alongside a `MachineShare` token and accepts deposits of a whitelisted asset. The exchange rate mirrors that of the future `Machine`, using a specified accounting token, which may differ from the deposit token. During the migration phase, both the deposited assets and ownership of the share token are transferred from the vault to the newly deployed `Machine` contract.

### Caliber

The `Caliber` contract serves as the execution engine, responsible for deploying assets to external protocols. On the Hub Chain, the Machine communicates directly with its associated Hub Caliber. Additional Caliber instances can be deployed on Spoke Chains to expand the protocol across networks.

#### Mailbox

Cross-chain communication between the Hub Machine and Spoke Calibers is facilitated through `CaliberMailbox` contracts. Each Spoke Caliber is deployed alongside a `CaliberMailbox` on its respective Spoke Chain. These mailbox contracts enable Spoke Calibers to communicate asynchronously with the Hub Machine, coordinating and tracking cross-chain fund transfers initiated or received by the Caliber.

#### Instructions

Calibers can manage and account for positions by executing authorized instructions, which leverage the [Weiroll](https://github.com/EnsoBuild/enso-weiroll) command-chaining framework. A large set of instructions can be pre-approved and registered in a Merkle Tree, whose root is stored in the caliber and used to verify authorization proof.

Instructions can be of four different types:

- **ACCOUNTING**: Calculates the current size of a position and updates it in the executing caliber's storage.
- **MANAGEMENT**: Modifies the size of a position. A `MANAGEMENT` instruction is always paired with an `ACCOUNTING` instruction to account for the changes it introduces.
- **HARVESTING**: Collects rewards earned by Caliber’s open positions from external protocols. `HARVESTING` instructions can collect rewards for multiple positions in a single operation. The rewards are moved from the external protocols’ reward distribution contracts to the Caliber contract.
- **FLASHLOAN_MANAGEMENT**: Modifies the size of a position in the context of a flash loan, as part of an outer `MANAGEMENT` instruction. A `FLASHLOAN_MANAGEMENT` instruction is always associated with a `MANAGEMENT` and an `ACCOUNTING` instructions.

Each `Instruction` object includes an `affectedTokens` list which can have various purpose for different instruction types. For `HARVESTING` and `FLASHLOAN_MANAGEMENT` instructions, this list is ignored.

Flash loans are a specialized use case that require a `FlashLoanModule` instance, classified as a periphery contract and excluded from this repository’s scope.

#### Assumptions

The protocol relies on specific assumptions on the instructions:

- **ACCOUNTING**:
  - They must consist solely of read actions.
  - The `affectedTokens` list must include exactly all tokens in which the position size is expressed. These tokens must be registered as base tokens in the executing caliber.
  - Their output state must start with an ordered list of amounts (one amount per slot) corresponding to the tokens in `affectedTokens`, followed by an end-of-args flag.
- **MANAGEMENT**:
  - The `affectedTokens` list must include exactly all tokens spent by the instruction. These tokens must also be registered as base tokens in the executing caliber.
- **HARVESTING**:
  - They are restricted to receive-only operations. They must not spend any tokens that are initially held by the Caliber.
- **FLASHLOAN_MANAGEMENT**:
  - They must not result in token balance changes for tokens that are not in the `affectedTokens` list of the associated `MANAGEMENT` instruction.

Furthermore, while positions can be represented by one or more receipt tokens (e.g. ERC20 tokens, NFTs, etc.) that calibers do not track, the protocol relies on the following assumptions when creating new positions within a given caliber:

- A given position cannot be denoted by more than 1 ID.
- A token cannot be both a base token and a position token.

#### Standard Operator Actions:

- Can account for one or multiple positions at a time.
- Can open, manage and close one or multiple positions at a time.
- Can harvest and swap external reward assets.
- Can swap a token into any base token.
- Can fetch net caliber aum and positions detail.
- Can initiate a transfer towards Hub Machine.

### SwapModule

The `SwapModule` contract serves as an external module, enabling calibers and machines to securely interact with external swap protocols using unverified calldata. The swapModule pulls funds from caller before execution and sends back output funds upon completion.

### Oracle Registry

The `OracleRegistry` contract acts as an aggregator of [Chainlink price feeds](https://docs.chain.link/data-feeds/price-feeds), and prices tokens in a reference currency (e.g. USD) using either one feed or a two feeds path.

### Chain Registry

The protocol uses Wormhole cross-chain queries to relay accounting data from Spoke Calibers to the Hub Machine. Since Wormhole relies on its own custom chain ID system, the `ChainRegistry` contract provides a mapping between standard EVM chain IDs and Wormhole chain IDs.

### Token Registry

The `TokenRegistry` contract maintains the association between token addresses on the Hub and Spoke Chains. It enables consistent identification and pricing of bridged assets across networks, ensuring accurate cross-chain accounting.

### Access Control

Contracts in this repository implement the [OpenZeppelin AccessManagerUpgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/access/manager/AccessManagerUpgradeable.sol). The Makina protocol provides an instance of `AccessManagerUpgradeable` with addresses defined by the Makina DAO, but institutions that require it can deploy machines with their own `AccessManagerUpgradeable`. See [PERMISSIONS.md](https://github.com/makinaHQ/makina-core/blob/main/PERMISSIONS.md) for full list of permissions.

Roles use in makina core contracts are defined as follows:

- `SUPER_ADMIN_ROLE` - roleId `0` - the Access Manager super admin. Can grant and revoke any role. Set by default in the Access Manager constructor.
- `MAKINA_ADMIN_ROLE` - roleId `1` - the address allowed to set the entities that manage strategies.
- `DEPLOYER_ROLE` - roleId `2` - the address allowed to deploy new strategies.
- `MAINTAINER_ROLE` - roleId `3` - the address allowed to perform setup and maintenance on core contracts.
