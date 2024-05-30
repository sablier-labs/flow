#!/usr/bin/env bash

# Pre-requisites:
# - foundry (https://getfoundry.sh)
# - bun (https://bun.sh)

# Strict mode: https://gist.github.com/vncsna/64825d5609c146e80de8b1fd623011ca
set -euo pipefail

# Delete the current artifacts
artifacts=./artifacts
rm -rf $artifacts

# Create the new artifacts directories
mkdir $artifacts \
  "$artifacts/interfaces" \
  "$artifacts/interfaces/erc20" \
  "$artifacts/interfaces/erc721" \
  "$artifacts/libraries"

# Generate the artifacts with Forge
FOUNDRY_PROFILE=optimized forge build

# Copy the production artifacts
cp out-optimized/SablierFlow.sol/SablierFlow.json $artifacts
cp out-optimized/SablierFlowNFTDescriptor.sol/SablierFlowNFTDescriptor.json $artifacts

interfaces=./artifacts/interfaces
cp out-optimized/ISablierFlow.sol/ISablierFlow.json $interfaces
cp out-optimized/ISablierFlowState.sol/ISablierFlowState.json $interfaces
cp out-optimized/ISablierFlowNFTDescriptor.sol/ISablierFlowNFTDescriptor.json $interfaces

erc20=./artifacts/interfaces/erc20
cp out-optimized/IERC20.sol/IERC20.json $erc20

erc721=./artifacts/interfaces/erc721
cp out-optimized/IERC721.sol/IERC721.json $erc721
cp out-optimized/IERC721Metadata.sol/IERC721Metadata.json $erc721

libraries=./artifacts/libraries
cp out-optimized/Errors.sol/Errors.json $libraries

# Format the artifacts with Prettier
bun prettier --write ./artifacts
