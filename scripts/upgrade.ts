import { ethers, upgrades,network,artifacts } from 'hardhat';
import { writeAbiAddr } from './artifact_saver';
import * as fs from 'fs';

async function main() {
    const [admin, user] = await ethers.getSigners();
    console.log('admin: ', admin.address, 'user: ', user.address);

    const deployNetwork  = network.name;
    let contractName = `Donate3`;
    let dir =  `deployments/dev/${deployNetwork}/${contractName}.json`;
    const proxyAddr: string = JSON.parse(fs.readFileSync(dir)).address;

    console.log('proxyAddr: ',proxyAddr);

    const upgradeableFactory = await ethers.getContractFactory('Donate3');

    await upgrades.upgradeProxy(proxyAddr, upgradeableFactory);

    console.log('proxy contract', proxyAddr);

    const donate3F = upgradeableFactory.attach(proxyAddr);
    
    let handlingFee = await donate3F.connect(admin).handlingFee();
    console.log('upgrade handlingFee: ',handlingFee);
    //Storage of deployment information
    await writeAbiAddr(artifacts, proxyAddr, contractName, network.name);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});