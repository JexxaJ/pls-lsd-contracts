# pls-lsd-contracts

Contracts is the foundation of the Forked ETH LSD stack from StaFi. It consists of LsdToken, UserDeposit, NodeDeposit and NetworkWithdraw and other contracts, which enables users to stake, unstake and withdraw, validators to run nodes with minimum amount of PLS and platform to manage solo and trust nodes. 

To learn more about PLS LSD stack, see [**Vouch LSD Documentation and Guide**](https://vouch.run)

a very brief diagrams of the workflow:

```mermaid
sequenceDiagram
participant  UserDeposit.sol
actor User
participant  NetworkWithdraw.sol

User->>UserDeposit.sol: stake PLS
UserDeposit.sol->>User: mint vPLS
User->>NetworkWithdraw.sol: unstake vPLS 
NetworkWithdraw.sol->>User: transfer PLS
```

```mermaid
sequenceDiagram
actor Admin
actor Node
participant NodeDeposit.sol

Admin->>NodeDeposit.sol: manage trust node
Node->>NodeDeposit.sol: create new validator
```

```mermaid
sequenceDiagram
Ethereum->>FeePool.sol: distribute priority fee
Ethereum->>NetworkWithdraw.sol: distribute validator rewards
```


```mermaid
sequenceDiagram
Voter->>NetworkBalances.sol: vote for user balances <br>and other proposals for the network
```

## License

The primary license for ETH LSD Contracts is the Business Source License 1.1 (BUSL-1.1), see [LICENSE](./LICENSE). Minus the following exceptions:

- Some [libraries](./contracts/libraries/) and [interfaces](./contracts/interfaces/) have a GPL license

Each of these files states their license type.
