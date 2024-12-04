## Makina Core Specifications

## Protocol

### Machine

The `Machine` contract is the central and user-facing component of the protocol. It handles deposits, redemptions and share price calculation.

#### Inboxes

Machine inboxes are deployed on the Hub chain. They handle incoming accounting messages from caliber inboxes and coordinate fund transfers between them.

- `HubMachineInbox` is used to communicate with an associated `HubCaliberInbox` on the same chain.
- `SpokeMachineInbox` is used to communicate with an associated `SpokeCaliberInbox` on a spoke chain, via bridging of message and funds.

### Caliber

The `Caliber` contract is the execution engine from which assets are deployed to external protocols.

#### Inboxes

Caliber inboxes are deployed on the same chain as their assocated caliber. They handle outgoing accounting messages sent to hub machine inboxes and coordinate fund transfers between them.

- `HubCaliberInbox` is used to communicate with an associated `HubMachineInbox`.
- `SpokeCaliberInbox` is used to communicate with an associated `SpokeMachineInbox`, via bridging of message and funds.

#### Instructions

Calibers can manage and account for positions by executing authorized instructions, which leverage the Weiroll command-chaining framework. A large set of instructions can be pre-approved and registered in a Merkle Tree, whose root is stored in the caliber and used to verify authorization proof.

#### Standard Operations:
- Can add a base token with `addBaseToken()`.
- Can account for a base token position with `accountForBaseToken()`.
- Can account for a non-base-token position with `accountForPosition()`.
- Can account for several non-base-token positions in a batch with `accountForPositionBatch()`.
- Can compute total caliber accounting value with `updateAndReportCaliberAUM()`.
- Can open, manage and close a position with `managePosition()`.
- Can swap a token into any base token with `swap()`.

### Swapper

The `Swapper` contract serves as an external module, enabling calibers and machines to securely interact with DEX aggregators using unverified calldata. The swapper pulls funds from caller before execution and sends back output funds upon completion.

### Oracle Registry

The `OracleRegistry` contract acts as an aggregator of Chainlink price feeds, and prices tokens in a reference currency (e.g. USD) using either one feed or a two feeds path.

### Access Control

Contracts in this repository implement the [OpenZeppelin AccessManager](https://docs.openzeppelin.com/contracts/5.x/api/access#accessmanager). The Makina protocol provides an instance of `AccessManager` with addresses defined by the Makina DAO, but institutions that require it can deploy machines with their own `AccessManager`. See [PERMISSIONS.md](https://github.com/makinaHQ/makina-core/blob/main/PERMISSIONS.md) for full list of permissions.

Roles use in makina core contracts are defined as follows:
- `ADMIN_ROLE` - roleId `0` - the Access Manager super admin. Can grant and revoke any role. Set by default in the Access Manager constructor.
