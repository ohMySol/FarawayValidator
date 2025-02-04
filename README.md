## Faraway Validator
This project demonstrates a reward mechanism for stakers of ERC-721 license nfts.

## Technology Stack & Tools
- [Solidity](https://docs.soliditylang.org/en/v0.8.28/) (Smart Contracts/Tests/Scripts)
- [Foundry](https://book.getfoundry.sh/) (Development Framework)

## Setting Up The Project
1. Clone/Download the Repository:
```shell
git https://github.com/ohMySol/FarawayValidator
```
2. Set up .env file:
Take a look in `.env.example` file. It is listed all necessary environment variables that should be set up to run a project successfully. For local testing it is enough to set up just `LOCAL_ADMIN_PK`.
3. Upload .env variables to shell:
```
$ source .env
```
4. Initialize the project:
```shell
$ make all
```
This command will run the commands for cleaning, updating, building and testing the project. After running this command you should see all tests are green, which means that the project was successfully initialized and it is ready for work.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Deploy
To deploy a contract I've prepared a Makefile with instructions. This simplified deployment process, because you don't need to write a long commands in terminal. You just need to set up one time `.env` file and then you just select the contract to deploy and network.

To deploy contracts, you can use the next command:
```shell
$ make deploy CONTRACT_NAME="<your contract name>" ARGS="<network name u are deploying to>".
```
Examples:
1. Deploy LicenseToken to localhost.
```shell
$ make deploy CONTRACT_NAME="LicenseToken"
``` 
2. Deploy Validator to Ethereum Sepolia network.
```shell
$ make deploy CONTRACT_NAME="Validator" ARGS="eth_sepolia"
```

### Deploy Detailed Instructions
1. Check if you upload your .env variable to the shell by command `echo $ADMIN_LOCAL_PK`. After this command you should see an Admin private key from your .env in the terminal. If you don't see this, then run this command `source .env` which will upload your .env variables to the shell.
2. `CONTRACT_NAME` parameter. Here you should paste the contract which u would like to deploy. Available contracts options for deployment at the moment: `Validator`, `LicenseToken`, `RewardToken`.
3. `ARGS` parameter. It stands for network name to which you would like to deploy your contract. Available networks options for deployment at the moment: `eth_mainnet_fork`, `eth_sepolia`, `no value` - means you deploying to localhost.

### Before Deploying To Testnets
1. When deploying a `Validator` to `eth_mainnet_fork` or `eth_sepolia` netoworks, make sure that you pasted a `licenseToken` and `rewardToken` addresses in `HelperConfig.s.sol` file in appropriate network configs.
2. When deploying to `eth_mainnet_fork` or `eth_sepolia` netoworks, make sure that you funded a deployer account with some ETH.

### Automatic Verification
1. If u deploying to Tenderly or Amoy, this Make-script will automatically verify your contract.

### Localhost Specific
1. When you deploy to a local environment (like Anvil) using a Makefile or a deployment script, the Anvil process itself often runs in the background. However, when you execute a `make` command that includes `anvil &` (running Anvil in the background), it starts Anvil and then completes the make command. This can make it seem like Anvil has "stopped working" because the terminal will show that the `make` command has finished.\
But in reality:
   - Anvil is running in the background due to the `&` at the end of the command, which allows it to run asynchronously.
   - `make` command finishes after starting Anvil, and it doesn't keep an interactive session with the running process.
   
Once the deployment completes, even if the terminal shows that the make command is finished, the Anvil process is still running and **you can interact with the deployed contract**.\
To confirm that Anvil is running in the background, you can check with the following: `lsof -i :8545`.\

## Problems to solve
1. Remove validator from `validators` array, if he/she withdraws all license tokens.
2. Improve the `epochEnd()` function. Atm I am iterating over the whole array which can lead to out of gas error or DoS attack. For this I can use batch operations to calculate and distribute rewards for a batch of validators.