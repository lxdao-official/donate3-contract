import { ethers,network,artifacts } from "hardhat";
import { writeAbiAddr } from './artifact_saver';

async function main() {
  // const factory = await ethers.getContractFactory("Donate3");
  // const donate3 = await factory.deploy("ETH");
  // await donate3.deployed();

// eas schemaId: 0x2fd8b1cc54de5cabcf62ecaa1f6f3317a980769aab4470396e5c912bfe325752
// attester address: 0x75C6eDBAE13C0989b3191Fbe4c940df61DDe96BE
// resolver address: 0xD94C5a8915AF66650DC66adeC4eE658Ea6428cbe

  const donate3 = await ethers.deployContract("Donate3",["ETH","0x75C6eDBAE13C0989b3191Fbe4c940df61DDe96BE","0x2fd8b1cc54de5cabcf62ecaa1f6f3317a980769aab4470396e5c912bfe325752"]);

  console.log("donate3 address:", await donate3.getAddress());
  await writeAbiAddr(artifacts, await donate3.getAddress(), "Donate3", network.name);
  
  //0x1D9021fbE80a7Ce13897B5757b25296d62dDe698 donate sepolia
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
