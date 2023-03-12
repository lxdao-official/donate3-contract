import { ethers,network,artifacts } from "hardhat";
import { writeAbiAddr } from './artifact_saver';

async function main() {
  const factory = await ethers.getContractFactory("Donate3");
  const donate3 = await factory.deploy("ETH");
  await donate3.deployed();

  console.log("Donate3 Deployed to:", donate3.address);
  await writeAbiAddr(artifacts, donate3.address, "Donate3", network.name);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
