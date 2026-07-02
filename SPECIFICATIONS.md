## Makina Core Specifications

### Machine

The `Machine` contract is the central and user-facing component of the protocol. It handles deposits, redemptions and share price calculation.

#### Machine Share Token

Each machine controls a share token, which represents users' shares in a given strategy. The machine has minting and burning rights on the token.

#### Share price calculation

The share price consists essentially of the ratio between share token supply and the last calculated total machine AUM. In order to mitigate donation attacks, the conversion includes a `shareTokenDecimalsOffset` value representing the decimal offset between the accounting token and the share token. By setting the ratio between virtual shares and virtual assets in the vault, the offset also determines the initial exchange rate.

#### Deposits and Redemptions

Machines serve as the user-facing contracts for deposits and redemptions. However, the actual processing is handled by a dedicated deposit module and a redemption queue, both of which are excluded from this repository’s scope. This design allows strategies to implement various deposit and redemption flows, whether permissionless, permissioned, queued, or synchronous. When needed, settlement can be performed by the operator.

Since deposits, redemptions, and share price calculation occur independently, it is the operator's duty to take precautions to prevent price manipulation and ensure fairness between users.

#### Fees

After each total AUM computation, machines apply three types of fees by inflating the share supply:

- Management Fees
- Security Module Fees
- Performance Fees

Management and Security Module fees will be calculated based on share supply, independently of performance. Performance fees, on the other hand, are based on both share supply and share price performance. Fee calculations are delegated to a `FeeManager` module, classified as a periphery contract and excluded from this repository’s scope.

#### Cross-chain Accounting

In order to compute a machine's total AUM, accounting data of each caliber needs to be aggregated. Each caliber mailbox (see [Caliber](#mailbox) section) exposes a view function returning the detailed AUM of the associated caliber. This data can be retrieved and then aggregated in the machine contract storage.

For spoke calibers, the protocol relies on the [Chainlink Runtime Environment (CRE)](https://docs.chain.link/cre) to relay this accounting data to the Hub Machine. CRE is Chainlink's off-chain compute platform, where a workflow reads spoke calibers accounting snapshots, and resulting reports are delivered on-chain by a Chainlink forwarder. The Machine receives them through its `onReport` callback, which authenticates the forwarder and validates the reports workflow metadata against the set of authorized IDs before the snapshots are aggregated into storage.

The Security Council is fully trusted to bypass CRE: it can call `onReport` directly to publish spoke caliber accounting snapshots itself, without going through the CRE forwarder or the associated metadata validation. This serves as a fallback should the CRE relaying path become unavailable.

#### Cross-chain Transfers

To move funds between the hub chain and spoke chains, the protocol supports multiple liquidity bridging protocols through a modular bridge adapter system. At each stage of a bridge transfer, the involved funds are accounted for in the machine’s AUM calculation.

See more in the [Liquidity Bridging](#liquidity-bridging) section.

#### Spoke Caliber Disabling

A registered spoke caliber can be disabled, and later re-enabled. A disabled spoke caliber is skipped in the machine's total AUM computation, and the machine can no longer schedule outgoing bridge transfers towards it. This is used once a spoke caliber has become empty and no longer relevant, to avoid having to keep relaying its accounting data to the machine.

Disabling requires:

- Zero spoke caliber net AUM as per the last received spoke data.
- No pending outgoing bridge transfer towards it.
- No pending incoming bridge transfer from it, as per the last received spoke data.

These three conditions correspond to the three ways a spoke caliber contributes to total AUM, so disabling a caliber removes no value that is being counted at that time. Figures reported by the spoke need not be recent, and disabling remains permitted even when the last report is older than the caliber accounting staleness threshold. A spoke caliber can only receive funds through an outgoing transfer from the machine, which the machine tracks in its own, always-current records. Since disabling requires no such transfer to be pending, a caliber whose last reported AUM was zero can reasonably be considered still empty.

Disabling can be reversed at any time by re-enabling. Incoming bridge transfers from a disabled spoke caliber also remain accepted by design: should a disabled caliber ever hold funds, they could still be bridged back and received as idle tokens on the hub, rather than being stranded.

#### Standard Operator Actions:

- Can store the last accounting data from spoke calibers.
- Can recompute and update the total AUM, and mint fees.
- Can initiate a transfer towards a caliber.

### Pre-Deposit Vault

The `PreDepositVault` is used during pre-deposit campaigns to onboard users capital ahead of a `Machine` deployment. It is deployed alongside a `MachineShare` token and accepts deposits of a whitelisted asset. The exchange rate mirrors that of the future `Machine`, using a specified accounting token, which may differ from the deposit token. During the migration phase, both the deposited assets and ownership of the share token are transferred from the vault to the newly deployed `Machine` contract.

### Caliber

The `Caliber` contract serves as the execution engine, responsible for deploying assets to external protocols. On the hub chain, the machine communicates directly with its associated hub caliber. An additional caliber can be deployed on any supported spoke chain to expand the strategy.

#### Mailbox

Cross-chain communication between the hub machine and spoke calibers is facilitated through `CaliberMailbox` contracts. Each spoke `Caliber` is deployed alongside a `CaliberMailbox` on its respective spoke chain. The `CaliberMailbox` acts as a machine endpoint from the `Caliber`’s perspective. It abstracts away chain-specific logic, managing liquidity bridging for transfers to and from the hub machine, and it also handles access control setup.

#### Instructions

Calibers can manage and account for positions by executing authorized instructions, which leverages the [Weiroll](https://github.com/EnsoBuild/enso-weiroll) command-chaining framework. A large set of instructions can be pre-approved and registered in a Merkle Tree, whose root is stored in the caliber and used to verify authorization proof.

Instructions can be of four different types:

- **ACCOUNTING**: Calculates the current size of a position and updates it in the executing caliber's storage.
- **MANAGEMENT**: Modifies the size of a position. A `MANAGEMENT` instruction is always paired with an `ACCOUNTING` instruction to account for the changes it introduces.
- **HARVEST**: Collects rewards earned by Caliber’s open positions from external protocols. A single `HARVEST` instruction can aggregate rewards from multiple positions and transfer them to the Caliber contract.
- **FLASHLOAN_MANAGEMENT**: Modifies the size of a position in the context of a flash loan, as part of an outer `MANAGEMENT` instruction. A `FLASHLOAN_MANAGEMENT` instruction is always associated with a `MANAGEMENT` instruction and can only be executed in its scope.

Each `Instruction` object includes an `affectedTokens` list which can have various purposes for different instruction types. For `HARVEST` and `FLASHLOAN_MANAGEMENT` instructions, this list is ignored.

Flash loans are a specialized use case that require a `FlashLoanModule` instance, classified as a periphery contract and excluded from this repository’s scope.

#### Assumptions

The protocol relies on specific assumptions on the instructions:

- **ACCOUNTING**:
  - They must not introduce changes in position states or token balances.
  - The `affectedTokens` list must include exactly all tokens in which the position size is expressed. These tokens must be registered as base tokens in the executing caliber.
  - Their output state must start with an ordered list of amounts (one amount per slot) corresponding to the tokens in `affectedTokens`, followed by an end-of-args flag.
- **MANAGEMENT**:
  - The `affectedTokens` list must include exactly all tokens spent by the instruction. These tokens must also be registered as base tokens in the executing caliber.
- **HARVEST**:
  - They are restricted to receive-only operations. They must not spend any tokens that are initially held by the caliber.
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
- Can initiate a transfer towards the hub machine.

### SwapModule

The `SwapModule` contract serves as an external module, enabling calibers and machines to securely interact with external swap protocols using unverified calldata. The swapModule pulls funds from the caller before execution and sends back output funds upon completion.

### Oracle Registry

The `OracleRegistry` contract acts as an aggregator of [Chainlink price feeds](https://docs.chain.link/data-feeds/price-feeds), and prices tokens in a reference currency (e.g. USD) using either one feed or a two-feed path.

### Token Registry

The `TokenRegistry` maps each token to its equivalent token addresses on the hub and spoke chains. Bridge transfers rely on these mappings to identify their input and output tokens, which are assumed to represent the same asset and use the same number of decimals. Correct configuration on every chain is required for consistent identification, pricing, and accounting across chains.

### Liquidity Bridging

Liquidity can be bridged between a hub machine and a spoke caliber via their respective bridge adapters. The protocol provides a dedicated bridge adapter implementation for each supported external bridge protocol.

Bridging is a five-step process, executed by the operator, and functions symmetrically in both directions: Hub → Spoke and Spoke → Hub.

1. Schedule the outgoing transfer on the sender side.
2. Authorize the incoming transfer on the recipient side by registering the message hash.
3. Send the outgoing transfer through the bridge protocol from the sender side.
4. Receive the incoming transfer from the bridge protocol on the recipient side.
5. Claim the transfer on the recipient side to finalize fund delivery.

For transfers from a spoke caliber to the hub machine, the spoke accounting snapshot that records the outbound transfer must be reported to the machine before the inbound transfer is claimed. The machine rejects the claim until the recorded cumulative outbound amount covers the transfer. This ordering ensures that the funds are removed from the spoke side of the machine's accounting view before they are added to the hub side.

#### Emergency Bridge State Reset

If an operator or external bridge protocol deviates from expected behavior, the Security Council can reset the bridging state for a given token on the Machine and each involved CaliberMailbox. Each reset clears the bridge counters for that token and withdraws all funds held by the endpoint's bridge adapters to their parent Machine or Caliber.

The reset is a coordinated emergency procedure. Calling it while transfers are still in flight or omitting an involved chain can make later receipts inconsistent with the cleared counters. The Security Council may use the following procedure:

1. Enable recovery mode on the Machine and on the Caliber and CaliberMailbox contracts for every involved spoke.
2. Wait until every pending bridge transfer involving the token has reached its destination bridge adapter.
3. Reset the bridging state for the token on every involved CaliberMailbox using its local token address.
4. Report a fresh accounting snapshot for every reset CaliberMailbox.
5. Reset the bridging state on the Machine using the token address on the hub chain.

### Access Control

Contracts in this repository implement the [OpenZeppelin AccessManagerUpgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/access/manager/AccessManagerUpgradeable.sol). The Makina protocol provides an instance of `AccessManagerUpgradeable` with addresses defined by the Makina DAO, but institutions that require it can deploy machines with their own `AccessManagerUpgradeable`. See [PERMISSIONS.md](https://github.com/makinaHQ/makina-core/blob/main/PERMISSIONS.md) for full list of permissions.

Roles used in Makina Core contracts are defined as follows:

- `ADMIN_ROLE` - roleId `0` - Super admin of the Access Manager. Authorized to perform Access Manager configuration actions.
- `INFRA_CONFIG_ROLE` - roleId `1` - Authorized to configure shared core contracts.
- `STRATEGY_DEPLOYMENT_ROLE` - roleId `2` - Authorized to deploy new strategies.
- `STRATEGY_COMPONENTS_LINKING_ROLE` - roleId `3` - Authorized to link strategy contracts together.
- `STRATEGY_MANAGEMENT_CONFIG_ROLE` - roleId `4` - Authorized to designate the entities responsible for managing strategies.
- `STRATEGY_FEE_CONFIG_ROLE` - roleId `5` - Authorized to configure fee parameters in strategy periphery contracts.
- `INFRA_UPGRADE_ROLE` - roleId `6` - Authorized to upgrade proxys and beacons, and register contracts in the core registry.
- `GUARDIAN_ROLE` - roleId `7` - Authorized to cancel operations scheduled with the other roles.
