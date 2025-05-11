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

test-create-pool:
	forge script scripts/CreatePool.s.sol \
	--rpc-url ${LISK_TESTNET_RPC} \
	--broadcast \
	--skip-simulation \
	--private-key ${PRIVATE_KEY}

test-limit-order:
	forge script scripts/CreateLimitOrder.s.sol \
	--rpc-url ${LISK_TESTNET_RPC} \
	--broadcast \
	--skip-simulation \
	--private-key ${PRIVATE_KEY}

test-execute-order:
	forge script scripts/CreateExecuteOrder.s.sol \
	--rpc-url ${LISK_TESTNET_RPC} \
	--broadcast \
	--skip-simulation \
	--private-key ${PRIVATE_KEY}

verify-hivecore-contract-testnet:
	forge verify-contract \
	--rpc-url ${LISK_TESTNET_RPC} \
	0x27b698e1dEf9887D891cfB31fB0904BA31BB9110 \
	src/HiveCore.sol:HiveCore \
	--verifier blockscout \
	--verifier-url ${BLOCKSCOUT_LISK_TESTNET}
	--compiler-version 0.8.20

clean:
	forge clean