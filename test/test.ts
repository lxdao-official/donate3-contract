import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { MerkleTree } from "merkletreejs";
import { keccak256 } from "@ethersproject/keccak256";
import { parseBytes32String } from "@ethersproject/strings/src.ts/bytes32";
import { toUtf8String } from "@ethersproject/strings/src.ts/utf8";

describe("Donate3 Test", function () {
  const pidInit = 10001;
  const pid1 = 10002;
  const pid2 = 10003;
  const pid3 = 10003;

  async function deployDonateFixture() {
    const [owner, feeSetter, user, userReceive, donor, ...allowListAccounts] =
      await ethers.getSigners();

    const factory = await ethers.getContractFactory("Donate3");

    const Donate3 = await factory.deploy(feeSetter.address);

    // merkle tree
    const allowListAddresses = allowListAccounts.map(
      (account) => account.address,
    );
    const leaves = allowListAddresses.map((addr) => keccak256(addr));
    const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    const root = merkleTree.getRoot();
    await Donate3.setFreeMerkleRoot(root);

    return {
      Donate3,
      owner,
      user,
      userReceive,
      donor,
      allowListAccounts,
      merkleTree,
    };
  }

  async function initProjects() {
    const { Donate3, user, userReceive } = await loadFixture(
      deployDonateFixture,
    );
    await Donate3.connect(user).mint(
      user.address,
      pidInit,
      userReceive.address,
    );
  }

  it("Should set the right owner", async function () {
    const { Donate3, owner } = await loadFixture(deployDonateFixture);
    expect(await Donate3.owner()).to.equal(owner.address);
  });

  it("Add project", async function () {
    const { Donate3, user, userReceive } = await loadFixture(
      deployDonateFixture,
    );
    await Donate3.connect(user).mint(user.address, pid1, userReceive.address);
    const { pid } = await Donate3.getProject(user.address, 0);

    expect(pid.toString()).to.equal(`${pid1}`);
  });

  it("Donate ETH", async function () {
    const { Donate3, user, allowListAccounts, merkleTree } = await loadFixture(
      deployDonateFixture,
    );

    await initProjects();

    const donor = allowListAccounts[0];
    const proof = merkleTree.getHexProof(keccak256(donor.address));

    const project = await Donate3.getProject(user.address, 0);

    const balance1 = await ethers.provider.getBalance(donor.address);
    const balance2 = await ethers.provider.getBalance(project.rAddress);
    console.log(
      `user:${ethers.utils.formatEther(
        balance1,
      )},userReceive:${ethers.utils.formatEther(balance2)}`,
    );

    // merkle tree

    const amountIn = ethers.utils.parseEther("1.5");

    await Donate3.connect(donor).donateETH(
      pidInit,
      amountIn,
      user.address,
      ethers.utils.toUtf8Bytes("Hello donate3"),
      proof,
      {
        value: amountIn,
      },
    );

    const balance3 = await ethers.provider.getBalance(donor.address);
    const balance4 = await ethers.provider.getBalance(project.rAddress);
    console.log(
      `user:${ethers.utils.formatEther(
        balance3,
      )},userReceive:${ethers.utils.formatEther(balance4)}`,
    );

    console.log("Records:");

    const records = await Donate3.getRecords(user.address, pidInit);
    for (let i = 0; i < records.length; i++) {
      const record = records[i];
      console.log(
        `symbol:${ethers.utils.parseBytes32String(record.symbol)}, amount: ${
          record.amount
        }, timestamp: ${record.timestamp}, msg: ${ethers.utils.toUtf8String(
          record.msg,
        )}`,
      );
    }
  });
});
