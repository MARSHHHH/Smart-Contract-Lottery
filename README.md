# Smart Contract Lottery

This repository contains the implementation of a decentralized lottery system using smart contracts. The project leverages Chainlink VRF (Verifiable Random Function) for randomness and Chainlink Keepers for automation.

## About

The Smart Contract Lottery allows users to enter a lottery by paying an entrance fee. The lottery periodically selects a random winner using Chainlink VRF and transfers the accumulated funds to the winner. The process is automated using Chainlink Keepers.

## Documentation
https://book.getfoundry.sh/

## What we want it to do?

1. Users can enter by paying for a ticket.
    The ticket fee are going to go to the winner during the draw.
2. After X period of time, the lottery will automatically draw a winner.
    This will be done programtically.
3. Using ChainLink VRF & Chanlink Automation
    Chainlink VRF -> Randomness
    Chainlink Automation -> Time based trigger

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```
1. Write some deploy scripts
2. Write out tests
    1. On local chain
    2. Forked Testnet
    3. Forked Mainnet

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```


# Smart-Contract-Lottery
