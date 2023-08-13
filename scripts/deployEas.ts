import { ethers } from "hardhat";
import Contracts from '../components/Contracts';
import { SchemaRegistry, EAS, ExampleAttester, ExampleUintResolver } from '../typechain-types';
import { getSchemaUID } from '@ethereum-attestation-service/eas-sdk';
import { expect } from './helpers/Chai';
import { string } from 'hardhat/internal/core/params/argumentTypes';
import  SchemaRegistryABI from '../test/SchemaRegistry.json';

async function main() {
    //let registry: SchemaRegistry;
    //let eas: EAS;
    let attester: ExampleAttester;
    let resolver: ExampleUintResolver;
  
    const schema = 'address donor, address donee, uint256 amount, address token';
    let schemaId: string;
  
    // registry = await Contracts.SchemaRegistry.deploy();
    //eas = await Contracts.EAS.deploy(await registry.getAddress());

    let easAddress =  "0xC2679fBD37d54388Ce493F1DB75320D236e1815e";
    attester = await Contracts.ExampleAttester.deploy(easAddress);
    resolver = await Contracts.ExampleUintResolver.deploy(easAddress);

    const [admin, user] = await ethers.getSigners();
    const registerAddress = "0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0";
    const registry = new ethers.Contract(registerAddress, SchemaRegistryABI.abi, admin);

    await registry.register(schema, await resolver.getAddress(), true);
    schemaId = getSchemaUID(schema, await resolver.getAddress(), true);
    console.log("eas schemaId:", schemaId);
    console.log("attester address:", await attester.getAddress());
    console.log("resolver address:", await resolver.getAddress());

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
