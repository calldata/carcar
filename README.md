## Usage

### Pre Requisites

Before running any command, make sure to install dependencies:

```sh
$ yarn install
```

### env variable configuation

```sh
$ copy .env.example .env
```

change `MNEMONIC` and `INFURA_API_KEY` with yours

### Compile

Compile the smart contracts with Hardhat:

```sh
$ yarn compile
```

### Test

Run the Mocha tests:

```sh
$ yarn test
```

### Deploy contract to netowrk (requires Mnemonic and infura API key)

```
npx hardhat run --network rinkeby ./scripts/deploy.ts
```

### Validate a contract with etherscan (requires API ke)

```
npx hardhat verify --network <network> <DEPLOYED_CONTRACT_ADDRESS> "Constructor argument 1"
```
