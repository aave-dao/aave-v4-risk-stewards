# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# coverage :; forge coverage --report lcov && \
# 	lcov --remove ./lcov.info -o ./lcov.info.p \
# 	'test/*' \
# 	'scripts/examples/*' \
# 	'src/updates/*' \
# 	'scripts/*' \
# 	&& genhtml ./lcov.info.p -o report --branch-coverage \
# 	&& coverage=$$(awk -F '[<>]' '/headerCovTableEntryHi/{print $3}' ./report/index.html | sed 's/[^0-9.]//g' | head -n 1); \
# 	wget -O ./report/coverage.svg "https://img.shields.io/badge/coverage-$${coverage}%25-brightgreen"

# Coverage
coverage-base :; FOUNDRY_PROFILE=coverage forge coverage --report lcov --no-match-coverage "(scripts|test|deployments|mocks|examples|updates)"
coverage-clean :; lcov --rc derive_function_end_line=0 --remove ./lcov.info -o ./lcov.info.p --ignore-errors inconsistent
coverage-report :; genhtml ./lcov.info.p -o report --branch-coverage --rc derive_function_end_line=0 
coverage-badge :; coverage=$$(awk -F '[<>]' '/headerCovTableEntryHi/{print $3}' ./report/index.html | sed 's/[^0-9.]//g' | head -n 1); \
	wget -O ./report/coverage.svg "https://img.shields.io/badge/coverage-$${coverage}%25-brightgreen"
coverage :
	make coverage-base
	make coverage-clean
	make coverage-report
	make coverage-badge


# Build & test
build  :; forge build --sizes
test   :; forge test -vvv

# Utilities
download :; cast etherscan-source --chain ${chain} -d contracts/etherscan/${chain}_${address} ${address}
git-diff :
	@mkdir -p diffs
	@npx prettier ${before} ${after} --write
	@printf '%s\n%s\n%s\n' "\`\`\`diff" "$$(git diff --no-index --diff-algorithm=patience --ignore-space-at-eol ${before} ${after})" "\`\`\`" > diffs/${out}.md

# Deploy
deploy-ledger :; FOUNDRY_PROFILE=${chain} forge script ${contract} --rpc-url ${chain} $(if ${dry},--sender 0x25F2226B597E8F9514B3F68F00f494cF4f286491 -vvvv, --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --verify --verifier etherscan -vvvv --slow --broadcast)
deploy-pk :; FOUNDRY_PROFILE=${chain} forge script ${contract} --rpc-url ${chain} $(if ${dry},--sender 0x25F2226B597E8F9514B3F68F00f494cF4f286491 -vvvv, --private-key ${PRIVATE_KEY} --verify --verifier etherscan -vvvv --slow --broadcast)

# make run-script network=mainnet contract=scripts/examples/EthereumExample.sol:EthereumExample broadcast=false generate_diff=true skip_timelock=true
run-script:; forge script ${contract} --rpc-url ${network} --sig "run(bool, bool, bool)" ${broadcast} ${generate_diff} ${skip_timelock} -vv
