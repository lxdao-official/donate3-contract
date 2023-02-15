import { ethers, upgrades,network,artifacts } from 'hardhat';
import { writeAbiAddr } from './artifact_saver';

async function main() {
  const [admin, user] = await ethers.getSigners();
  console.log('admin: ', admin.address, 'user: ', user.address);

  const upgradeFactory = await ethers.getContractFactory("Donate3");
  const donate3 = await upgrades.deployProxy(
    upgradeFactory,
    ["ETH"],
    {kind:'uups'}
  );
  
  console.log("Donate3 Deployed to:", donate3.address);
  //Storage of deployment information
  await writeAbiAddr(artifacts, donate3.address, "Donate3", network.name);

  console.log('handleFee: ' ,await donate3.handlingFee());
  await donate3.connect(admin).setHandleFee(19);
  console.log('set handleFee: ' ,await donate3.handlingFee());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
