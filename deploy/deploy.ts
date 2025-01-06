import { Addressable } from "ethers";
import hre from "hardhat";
import { Deployer } from "@matterlabs/hardhat-zksync";
import { Wallet, Provider } from "zksync-ethers";

// CLI to run: `npx hardhat deploy-zksync --script deployZkSync.ts --config hardhat.config.zkSync.ts --network zkSyncTestnet/zkSyncMainnet`
export default async function () {
  const network = await hre.network.config;

  const provider = new Provider(hre.network.config.url);
  const deployerAddressPV = new Wallet(process.env.PRIVATE_KEY as string).connect(provider);
  const deployerAddress = deployerAddressPV.address;

  if (!deployerAddress) {
    console.error("Please set the PRIVATE_KEY in your .env file");
    return;
  }

  const deployer = new Deployer(hre, deployerAddressPV);
  const safeMultisig = "0xD427d37B5F6d33f7D42C4125979361E011FFbfD9";

  const artifactSablierFlow = await deployer.loadArtifact("SablierFlow");
  const artifactNFTDescriptor = await deployer.loadArtifact("FlowNFTDescriptor");

  console.log("Deploying FlowNFTDescriptor...");
  const nftDescriptor = await deployer.deploy(artifactNFTDescriptor, []);
  const nftDescriptorAddress =
    typeof nftDescriptor.target === "string" ? nftDescriptor.target : nftDescriptor.target.toString();
  console.log("FlowNFTDescriptor deployed to:", nftDescriptorAddress);
  await verifyContract(nftDescriptorAddress, []);

  console.log("Deploying SablierFlow...");
  const flow = await deployer.deploy(artifactSablierFlow, [safeMultisig, nftDescriptorAddress]);
  const flowAddress = flow.target;
  console.log("SablierFlow deployed to:", flowAddress);
  await verifyContract(flowAddress, [safeMultisig, nftDescriptorAddress]);
}

const verifyContract = async (contractAddress: string | Addressable, verifyArgs: string[]): Promise<boolean> => {
  console.log("\nVerifying contract...");
  await new Promise((r) => setTimeout(r, 20000));
  try {
    await hre.run("verify:verify", {
      address: contractAddress.toString(),
      constructorArguments: verifyArgs,
      noCompile: true,
    });
  } catch (e) {
    console.log(e);
  }
  return true;
};
