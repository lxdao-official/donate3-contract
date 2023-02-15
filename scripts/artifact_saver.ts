import fs from 'fs';
import path from 'path';
import { Artifact } from 'hardhat/types';
import { writeFile } from 'fs/promises';

export async function writeAbiAddr(artifacts: { readArtifact: (name: string) => Promise<Artifact> }, addr: string, name: string, network: string): Promise<void> {
  const dir = `deployments/dev/${network}/`;
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir);
  }

  let artifact = await artifacts.readArtifact(name);

  const deployments: Record<string, string> = {};
  deployments['contractName'] = artifact.contractName;
  deployments['address'] = addr;

  const deploymentDevPath = path.resolve(__dirname, `../deployments/dev/${network}/${deployments["contractName"]}.json`);
  await writeFile(deploymentDevPath, JSON.stringify(deployments, null, 2));

  const abis: Record<string, unknown> = {};
  abis["contractName"] = artifact.contractName;
  abis["abi"] = artifact.abi;

  const deploymentAbiPath = path.resolve(__dirname, `../deployments/abi/${abis["contractName"]}.json`);
  await writeFile(deploymentAbiPath, JSON.stringify(abis, null, 2));
}

