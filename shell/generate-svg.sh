#!/usr/bin/env bash

# Notes:
# - There are four input arguments: progress, status, deposit amount, and duration

# Pre-requisites:
# - foundry (https://getfoundry.sh)
# - sd (https://github.com/chmln/sd)

# Strict mode: https://gist.github.com/vncsna/64825d5609c146e80de8b1fd623011ca
set -euo pipefail

# Run the Forge script and extract the SVG from stdout
output=$(forge script script/GenerateSVG.s.sol)

# Forge adds 'svg: string ' as a prefix before the SVG
# - The awk command records everything after the prefix, while filtering out empty lines
# - `sd \\"` '"'` removes the escape backslashes
# - `sd ^\"|\"$' ''` removes the starting and the ending double quotes
svg=$(echo "$output" | awk -F "svg: string " '/svg: string /{print $2; exit}' |  sd '\\"' '"' | sd '^"|"$' '')

# Generate the file name
name="tokenURI.svg"
sanitized="$(echo "$name" | sd ' ' '' )" # remove whitespaces

# Put the SVG in a file
mkdir -p "out-svg"
echo $svg > "out-svg/$sanitized"
