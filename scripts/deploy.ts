import { ethers,network,artifacts } from "hardhat";
import { writeAbiAddr } from './artifact_saver';

async function main() {
  // const factory = await ethers.getContractFactory("Donate3");
  // const donate3 = await factory.deploy("ETH");
  // await donate3.deployed();

/**
 * eas address 
 */
// sepolia 
// eas schemaId: 0x2fd8b1cc54de5cabcf62ecaa1f6f3317a980769aab4470396e5c912bfe325752
// attester address: 0x75C6eDBAE13C0989b3191Fbe4c940df61DDe96BE
// resolver address: 0xD94C5a8915AF66650DC66adeC4eE658Ea6428cbe

//opt goerli
// eas schemaId: 0x169f0b9c35c7520a5078ed31fda83eed6f9f15ec38299319c201cf8eb3e0712c
// attester address: 0xD9baA9416821f9eAAE2A8A1de13BfcC10aA3bd71
// resolver address: 0xd664d474496B90B4c3663bAbdb90A7D05B6A7d1a

  const donate3 = await ethers.deployContract("Donate3",["ETH","0x75C6eDBAE13C0989b3191Fbe4c940df61DDe96BE","0x2fd8b1cc54de5cabcf62ecaa1f6f3317a980769aab4470396e5c912bfe325752"]);

  console.log("donate3 address:", await donate3.getAddress());
  await writeAbiAddr(artifacts, await donate3.getAddress(), "Donate3", network.name);
  
  //https://sepolia.etherscan.io/address/0xf1f5219C777E44BCd2c2C43b6aCe2458169c0579#code
  //0xf1f5219C777E44BCd2c2C43b6aCe2458169c0579 donate sepolia
  //0x39fF8a675ffBAfc177a7C54556b815163521a8B7 donate opt goerli
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
