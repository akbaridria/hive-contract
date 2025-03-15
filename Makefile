include .env

.PHONY: all format compile test build clean deploy verify

all: build

format:
	forge fmt

compile:
	forge compile

test:
	forge test

build:
	forge build

clean:
	forge clean

deploy-edu-testnet:
	forge script script/HiveDeployment.s.sol \
	--broadcast \
	--private-key ${PRIVATE_KEY} \
	--verify \
	--verifier blockscout \
  	--verifier-url https://edu-chain-testnet.blockscout.com/api/