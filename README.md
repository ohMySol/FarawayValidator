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
