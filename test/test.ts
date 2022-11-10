import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { MerkleTree } from "merkletreejs";
import { keccak256 } from "@ethersproject/keccak256";

describe("Donate3 Test", function () {
  const pidInit =
    "kjzl6cwe1jw14amta5uvfbw2rg8ndifau3bmmqmlsc9d3w8vmj8zwtad3a4vrku";
  const pid1 =
    "kjzl6cwe1jw14amta5uvfbw2rg8ndifau3bmmqmlsc9d3w8vmj8zwtad3a4vrkk";
  const pid2 =
    "kjzl6cwe1jw14amta5uvfbw2rg8ndifau3bmmqmlsc9d3w8vmj8zwtad3a4vrkv";
  const pid3 =
    "kjzl6cwe1jw14amta5uvfbw2rg8ndifau3bmmqmlsc9d3w8vmj8zwtad3a4vrkm";

  const TokenASymbol = "TA";
  const TokenBSymbol = "TB";

  async function deployDonateFixture() {
    const [
      owner,
      user,
      userReceive,
      newUserReceive,
      donor,
      payee,
      ...allowListAccounts
    ] = await ethers.getSigners();

    const factory = await ethers.getContractFactory("Donate3");

    const Donate3 = await factory.deploy("ETH");

    // merkle tree
    const allowListAddresses = allowListAccounts.map(
      (account) => account.address,
    );
    const leaves = allowListAddresses.map((addr) => keccak256(addr));
    const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    const root = merkleTree.getRoot();
    await Donate3.setFreeMerkleRoot(root);

    const tokenFactory = await ethers.getContractFactory("TestERC20");
    const TokenA = await tokenFactory.deploy("TokenA", TokenASymbol);
    const TokenB = await tokenFactory.deploy("TokenB", TokenBSymbol);

    return {
      Donate3,
      TokenA,
      TokenB,
      owner,
      user,
      userReceive,
      newUserReceive,
      donor,
      payee,
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
      ethers.utils.toUtf8Bytes(pidInit),
      userReceive.address,
    );
  }

  it("1. Should set the right owner", async function () {
    const { Donate3, owner } = await loadFixture(deployDonateFixture);
    expect(await Donate3.owner()).to.equal(owner.address);
  });

  it("2. Add project", async function () {
    const { Donate3, user, userReceive } = await loadFixture(
      deployDonateFixture,
    );
    await Donate3.connect(user).mint(
      user.address,
      ethers.utils.toUtf8Bytes(pid1),
      userReceive.address,
    );
    const { pid } = (await Donate3.getProjectList(user.address))[0];

    expect(pid).to.equal(ethers.utils.hexlify(pid));
  });

  it("3. Update project", async function () {
    const { Donate3, user, userReceive, newUserReceive } = await loadFixture(
      deployDonateFixture,
    );

    await Donate3.connect(user).mint(
      user.address,
      ethers.utils.toUtf8Bytes(pidInit),
      userReceive.address,
    );

    await Donate3.connect(user).updateProjectReceive(
      user.address,
      ethers.utils.toUtf8Bytes(pidInit),
      newUserReceive.address,
    );

    const { rAddress } = (await Donate3.getProjectList(user.address))[0];

    expect(rAddress).to.equal(newUserReceive.address);
  });

  it("4. Burn project", async function () {
    const { Donate3, user, userReceive, newUserReceive } = await loadFixture(
      deployDonateFixture,
    );

    await Donate3.connect(user).mint(
      user.address,
      ethers.utils.toUtf8Bytes(pidInit),
      userReceive.address,
    );

    await Donate3.connect(user).burn(
      user.address,
      ethers.utils.toUtf8Bytes(pidInit),
    );

    const { status } = (await Donate3.getProjectList(user.address))[0];

    expect(status).to.equal(1);
  });

  it("5. Donate ETH", async function () {
    const { Donate3, user, allowListAccounts, merkleTree, userReceive } =
      await loadFixture(deployDonateFixture);

    await Donate3.connect(user).mint(
      user.address,
      ethers.utils.toUtf8Bytes(pidInit),
      userReceive.address,
    );

    // merkle tree
    const donor = allowListAccounts[0];
    const proof = merkleTree.getHexProof(keccak256(donor.address));

    const project = (await Donate3.getProjectList(user.address))[0];

    const userBalanceBefore = await ethers.provider.getBalance(
      project.rAddress,
    );

    const amountIn = ethers.utils.parseEther("1.51212");

    await Donate3.connect(donor).donateToken(
      ethers.utils.toUtf8Bytes(pidInit),
      amountIn,
      user.address,
      ethers.utils.toUtf8Bytes("Hello donate3"),
      proof,
      {
        value: amountIn,
      },
    );

    expect(
      (await ethers.provider.getBalance(project.rAddress))._hex,
    ).to.be.equal(userBalanceBefore.add(amountIn)._hex);
  });

  it("6. Donate ERC20", async function () {
    const { Donate3, TokenA, user, allowListAccounts, merkleTree } =
      await loadFixture(deployDonateFixture);

    await initProjects();

    // merkle tree
    const donor = allowListAccounts[0];
    const proof = merkleTree.getHexProof(keccak256(donor.address));

    const project = (await Donate3.getProjectList(user.address))[0];

    await TokenA.mint(donor.address, ethers.utils.parseEther("3.77774"));

    const userBalance = await TokenA.balanceOf(project.rAddress);

    const amountIn = ethers.utils.parseEther("2.3333");

    await TokenA.connect(donor).approve(Donate3.address, amountIn);

    await Donate3.connect(donor).donateERC20(
      ethers.utils.toUtf8Bytes(pidInit),
      TokenA.address,
      TokenASymbol,
      amountIn,
      user.address,
      ethers.utils.toUtf8Bytes("Hello donate3"),
      proof,
    );

    expect((await TokenA.balanceOf(project.rAddress))._hex).to.be.equal(
      userBalance.add(amountIn)._hex,
    );
  });

  it("7. Withdraw token", async function () {
    const { Donate3, user, payee } = await loadFixture(deployDonateFixture);

    const payeeBalance = await ethers.provider.getBalance(payee.address);

    const reserve = ethers.utils.parseEther("2.3333");
    const withdraw = ethers.utils.parseEther("1.56464646");

    await user.sendTransaction({
      to: Donate3.address,
      value: reserve,
    });

    await Donate3.withDrawToken(payee.address, withdraw);

    expect((await ethers.provider.getBalance(payee.address))._hex).to.be.equal(
      withdraw.add(payeeBalance)._hex,
    );

    expect(
      (await ethers.provider.getBalance(Donate3.address))._hex,
    ).to.be.equal(reserve.sub(withdraw)._hex);
  });

  it("8. Withdraw ERC20", async function () {
    const { Donate3, TokenA, payee } = await loadFixture(deployDonateFixture);

    const reserve = ethers.utils.parseEther("3.77774");
    const withdraw = ethers.utils.parseEther("2.533454646");

    await TokenA.mint(Donate3.address, reserve);

    await Donate3.withDrawERC20(
      TokenA.address,
      TokenASymbol,
      payee.address,
      withdraw,
    );

    expect((await TokenA.balanceOf(Donate3.address))._hex).to.be.equal(
      reserve.sub(withdraw)._hex,
    );

    expect((await TokenA.balanceOf(payee.address))._hex).to.be.equal(
      withdraw._hex,
    );
  });

  it("8. Withdraw ERC20 List", async function () {
    const { Donate3, TokenA, TokenB, payee } = await loadFixture(
      deployDonateFixture,
    );

    const reserve = ethers.utils.parseEther("3.77774");
    const withdrawTokenA = ethers.utils.parseEther("2.533454646");
    const withdrawTokenB = ethers.utils.parseEther("1.3333");

    await TokenA.mint(Donate3.address, reserve);

    await TokenB.mint(Donate3.address, reserve);

    await Donate3.withDrawERC20List(
      [TokenA.address, TokenB.address],
      [TokenASymbol, TokenBSymbol],
      payee.address,
      [withdrawTokenA, withdrawTokenB],
    );

    expect((await TokenA.balanceOf(Donate3.address))._hex).to.be.equal(
      reserve.sub(withdrawTokenA)._hex,
    );

    expect((await TokenB.balanceOf(Donate3.address))._hex).to.be.equal(
      reserve.sub(withdrawTokenB)._hex,
    );
  });
});
