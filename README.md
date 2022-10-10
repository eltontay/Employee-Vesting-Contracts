# ** Employee Token Compensation Smart Contract**

## **Introduction**

The task is to create smart contract(s) for an employee token compensation scheme. The compensation scheme rewards employee according to the overall performance of the protocol, signaled by the token's total supply.
This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

## **Getting Started**

Run Unit Tests

```shell
npx hardhat test
```

## **Background Information**

The underlying asset to be issued to the employee is the BLU token. The BLU token:

- has an initial supply of 1 million
- can be minted by the protocol through staking or bonding (ie. no fixed supply)

For the purpose of the employee compensation scheme, the BLU tokens will be disbursed from the company's wallet. The company wallet will obtain these BLU tokens via a vesting mechanism similar to pOHM.

When the supply of BLU reaches 100 million, the company will have 10 million tokens fully vested. Below is an example of how much is vested for the company at different token supply of BLU.

| BLU Total Supply | Vested BLU in Company’s Wallet |
| ---------------- | ------------------------------ |
| 1 million        | 100 thousand                   |
| 10 million       | 1 million                      |
| 100 million      | 10 million                     |
| 1 billion        | 10 million                     |

## **Objective**

Your goal is to create a token for the employee (hereby known as eBLU) that vests in a similar schedule. That is, when the BLU total supply hits 100 million, all the eBLU should be vested and redeemable for BLU.

The token should:

- vest the redemption linearly (ie. an employee holding 10k eBLU should be able to redeem 1k BLU when the BLU total supply is 10 million)
- allow the company to issue any amount of eBLU to any
- allow any holders of eBLU to redeem the BLU at any point in time

## **Time Taken**

~3 hours

## **Resources**

Building ERC20
https://docs.openzeppelin.com/contracts/4.x/wizard

Staking
https://github.com/smartcontractkit/defi-minimal/blob/main/contracts/Staking.sol

Vesting
https://github.com/abdelhamidbakhta/token-vesting-contracts/blob/main/contracts/TokenVesting.sol

minter role bytes32
0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6
