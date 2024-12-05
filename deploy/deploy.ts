import { ethers, run } from "hardhat";

async function main() {
  // Admin address
  const initialAdmin = "0xb1bef51ebca01eb12001a639bdbbff6eeca12b9f";

  console.log("Deploying FlowNFTDescriptor...");
  const FlowNFTDescriptor = await ethers.getContractFactory("FlowNFTDescriptor");
  const nftDescriptor = await FlowNFTDescriptor.deploy();

  await nftDescriptor.deployed();
  console.log("FlowNFTDescriptor deployed to:", nftDescriptor.address);

  console.log("Deploying SablierFlow...");
  // Deploy SablierFlow contract with the deployed NFT descriptor address
  const SablierFlow = await ethers.getContractFactory("SablierFlow");
  const flow = await SablierFlow.deploy(initialAdmin, nftDescriptor.address);

  await flow.deployed();
  console.log("SablierFlow deployed to:", flow.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
