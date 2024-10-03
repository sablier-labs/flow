// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { stdJson } from "forge-std/src/StdJson.sol";

import { BaseScript } from "./Base.s.sol";

contract TableCreator is BaseScript {
    using stdJson for string;
    using Strings for address;
    using Strings for string;
    using Strings for uint256;

    /// @dev The path to the file where the deployment addresses are stored.
    string internal deploymentFile;

    /// @dev Explorer URL mapped by the chain Id.
    mapping(uint256 chainId => string explorerUrl) internal explorerMap;

    /// @dev Chain names mapped by the chain Id.
    mapping(uint256 chainId => string name) internal nameMap;

    constructor(string memory deterministicOrNot) {
        // Populate the chain name map.
        populateChainNameMap();

        // Populate the explorer URLs.
        populateExplorerMap();

        // If there is no admin set for a specific chain, use the Sablier deployer.
        if (adminMap[block.chainid] == address(0)) {
            adminMap[block.chainid] = SABLIER_DEPLOYER;
        }

        // If there is no explorer URL set for a specific chain, use a placeholder.
        if (explorerMap[block.chainid].equal("")) {
            explorerMap[block.chainid] = "<explorer_url_missing>";
        }

        // If there is no chain name set for a specific chain, use the chain ID.
        if (nameMap[block.chainid].equal("")) {
            nameMap[block.chainid] = block.chainid.toString();
        }

        // Set the deployment file path.
        deploymentFile = string.concat("deployments/", deterministicOrNot, ".md");

        // Append the chain name to the deployment file.
        _appendToFile(string.concat("## ", nameMap[block.chainid], "\n\n"));
    }

    /// @dev Function to append the deployed addresses to the deployment file.
    function appendToFileDeployedAddresses(address flow, address flowNFTDescriptor) internal {
        string memory firstTwoLines = "| Contract | Address | Deployment |\n | :------- | :------ | :----------|";
        _appendToFile(firstTwoLines);

        string memory flowLine = _getContractLine({ contractName: "SablierFlow", contractAddress: flow.toHexString() });
        _appendToFile(flowLine);

        string memory flowNFTDescriptorLine =
            _getContractLine({ contractName: "FlowNFTDescriptor", contractAddress: flowNFTDescriptor.toHexString() });
        _appendToFile(flowNFTDescriptorLine);
    }

    /// @dev Populates the chain name map.
    function populateChainNameMap() internal {
        nameMap[42_161] = "Arbitrum";
        nameMap[43_114] = "Avalanche";
        nameMap[8453] = "Base";
        nameMap[84_532] = "Base Sepolia";
        nameMap[80_084] = "Berachain Bartio";
        nameMap[81_457] = "Blast";
        nameMap[168_587_773] = "Blast Sepolia";
        nameMap[56] = "BNB Smart Chain";
        nameMap[100] = "Gnosis";
        nameMap[1890] = "Lightlink";
        nameMap[59_144] = "Linea";
        nameMap[59_141] = "Linea Sepolia";
        nameMap[1] = "Mainnet";
        nameMap[333_000_333] = "Meld";
        nameMap[34_443] = "Mode";
        nameMap[919] = "Mode Sepolia";
        nameMap[2810] = "Morph Holesky";
        nameMap[10] = "Optimism";
        nameMap[11_155_420] = "Optimism Sepolia";
        nameMap[137] = "Polygon";
        nameMap[534_352] = "Scroll";
        nameMap[11_155_111] = "Sepolia";
        nameMap[53_302] = "Superseed Sepolia";
        nameMap[167_009] = "Taiko Hekla";
        nameMap[167_000] = "Taiko Mainnet";
    }

    /// @dev Populates the explorer map.
    function populateExplorerMap() internal {
        explorerMap[42_161] = "https://arbiscan.io/address/";
        explorerMap[43_114] = "https://snowtrace.io/address/";
        explorerMap[8453] = "https://basescan.org/address/";
        explorerMap[84_532] = "https://sepolia.basescan.org/address/";
        explorerMap[80_084] = "https://bartio.beratrail.io/address/";
        explorerMap[81_457] = "https://blastscan.io/address/";
        explorerMap[168_587_773] = "https://sepolia.blastscan.io/address/";
        explorerMap[56] = "https://bscscan.com/address/";
        explorerMap[1] = "https://etherscan.io/address/";
        explorerMap[100] = "https://gnosisscan.io/address/";
        explorerMap[59_144] = "https://lineascan.build/address/";
        explorerMap[59_141] = "https://sepolia.lineascan.build/address/";
        explorerMap[1890] = "https://phoenix.lightlink.io/address/";
        explorerMap[34_443] = "https://explorer.mode.network/address/";
        explorerMap[919] = "https://sepolia.explorer.mode.network/address/";
        explorerMap[2810] = "https://explorer-holesky.morphl2.io/address/";
        explorerMap[333_000_333] = "https://meldscan.io/address/";
        explorerMap[10] = "https://optimistic.etherscan.io/address/";
        explorerMap[11_155_420] = "https://sepolia-optimistic.etherscan.io/address/";
        explorerMap[137] = "https://polygonscan.com/address/";
        explorerMap[534_352] = "https://scrollscan.com/address/";
        explorerMap[11_155_111] = "https://sepolia.etherscan.io/address/";
        explorerMap[53_302] = "https://sepolia-explorer.superseed.xyz/address/";
        explorerMap[167_009] = "https://explorer.hekla.taiko.xyz/address/";
        explorerMap[167_000] = "https://taikoscan.io/address/";
    }

    /// @dev Append a line to the deployment file path.
    function _appendToFile(string memory line) private {
        vm.writeLine({ path: deploymentFile, data: line });
    }

    /// @dev Returns a string for a single contract line formatted according to the docs.
    function _getContractLine(
        string memory contractName,
        string memory contractAddress
    )
        private
        view
        returns (string memory)
    {
        string memory version = getVersion();
        version = string.concat("v", version);

        return string.concat(
            "| ",
            contractName,
            " | [",
            contractAddress,
            "](",
            explorerMap[block.chainid],
            contractAddress,
            ") | [",
            version,
            "](https://github.com/sablier-labs/v2-deployments/tree/main/",
            ") |"
        );
    }
}
