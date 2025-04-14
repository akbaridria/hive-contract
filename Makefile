include .env

.PHONY: all format compile test deploy verify deploy-edu-testnet test-flow-edu deploy-lisk-testnet

all: build

format:
	forge fmt

compile:
	forge compile

test:
	forge test

deploy-lisk-testnet:
	forge script scripts/HiveDeployment.s.sol \
	--rpc-url ${LISK_TESTNET_RPC} \
	--broadcast \
	--skip-simulation \
	--private-key ${PRIVATE_KEY} \
	--verify \
	--verifier blockscout \
	--verifier-url ${BLOCKSCOUT_LISK_TESTNET}

test-flow-testnet:
	forge script scripts/HiveFlowTest.s.sol \
	--rpc-url ${LISK_TESTNET_RPC} \
	--broadcast \
	--skip-simulation \
	--private-key ${PRIVATE_KEY}

verify-hivecore-contract-testnet:
	forge verify-contract \
	--rpc-url ${LISK_TESTNET_RPC} \
	0x8aaF54F2C894365204d4148bCD6719928aF38e1A \
	src/HiveCore.sol:HiveCore \
	--verifier blockscout \
	--verifier-url ${BLOCKSCOUT_LISK_TESTNET}
	--compiler-version 0.8.20

clean:
	forge clean