# Smart Contract Lottery

This repository contains the implementation of a decentralized lottery system using smart contracts. The project leverages Chainlink VRF (Verifiable Random Function) for randomness and Chainlink Keepers for automation.

## About

The Smart Contract Lottery allows users to enter a lottery by paying an entrance fee. The lottery periodically selects a random winner using Chainlink VRF and transfers the accumulated funds to the winner. The process is automated using Chainlink Keepers.

## What we want it to do?

1. Users can enter by paying for a ticket.
    The ticket fee are going to go to the winner during the draw.
2. After X period of time, the lottery will automatically draw a winner.
    This will be done programtically.
3. Using ChainLink VRF & Chanlink Automation
    Chainlink VRF -> Randomness
    Chainlink Automation -> Time based trigger

# Getting Started

## Requirements

[git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) version 2.47.1
[foundry](https://getfoundry.sh/) version 0.2.0 (e028b92 2024-11-11T00:26:04.968342000Z)


## Quickstart

'''
git clone https://github.com/MARSHHHH/Smart-Contract-Lottery
cd Smart-Contract-Lottery
forge build
'''

# Usage

## Start on local chain

```shell
$ make anvil
```

## Build

```shell
$ make build
```

## Test
Unite test
```shell
$ make test
```
Test Coverage
```shell
$ forge coverage
```

### Deploy

```shell
$ make deploy
```


# Smart-Contract-Lottery
