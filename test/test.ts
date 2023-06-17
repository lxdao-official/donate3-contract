import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { MerkleTree } from "merkletreejs";
import { keccak256 } from "@ethersproject/keccak256";

describe("Donate3 Test", function () {
  const pidInit = 10001;
  const pid1 = 10002;
  const pid2 = 10003;
  const pid3 = 10003;

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
  }

  it("1. Should set the right owner", async function () {
    const { Donate3, owner } = await loadFixture(deployDonateFixture);
    expect(await Donate3.owner()).to.equal(owner.address);
  });

  it("2. Donate ETH", async function () {
    const { Donate3, user, allowListAccounts, merkleTree, userReceive } =
      await loadFixture(deployDonateFixture);

    // merkle tree
    const donor = allowListAccounts[0];
    const proof = merkleTree.getHexProof(keccak256(donor.address));

    const userBalanceBefore = await ethers.provider.getBalance(
      userReceive.address,
    );

    const amountIn = ethers.utils.parseEther("1.51212");

    await Donate3.connect(donor).donateToken(
      amountIn,
      userReceive.address,
      ethers.utils.toUtf8Bytes("Hello donate3"),
      proof,
      {
        value: amountIn,
      },
    );

    expect(
      (await ethers.provider.getBalance(userReceive.address))._hex,
    ).to.be.equal(userBalanceBefore.add(amountIn)._hex);
  });

  it("3. Donate ERC20", async function () {
    const { Donate3, TokenA, user, allowListAccounts, merkleTree,userReceive } =
      await loadFixture(deployDonateFixture);

   // await initProjects();

    // merkle tree
    const donor = allowListAccounts[0];
    const proof = merkleTree.getHexProof(keccak256(donor.address));

    await TokenA.mint(donor.address, ethers.utils.parseEther("3.77774"));

    const userBalance = await TokenA.balanceOf(userReceive.address);

    const amountIn = ethers.utils.parseEther("2.3333");

    await TokenA.connect(donor).approve(Donate3.address, amountIn);

    await Donate3.connect(donor).donateERC20(
      TokenA.address,
      TokenASymbol,
      amountIn,
      userReceive.address,
      ethers.utils.toUtf8Bytes("Hello donate3"),
      proof,
    );

    expect((await TokenA.balanceOf(userReceive.address))._hex).to.be.equal(
      userBalance.add(amountIn)._hex,
    );
  });

  it("4. Withdraw token", async function () {
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

  it("5. Withdraw ERC20", async function () {
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

  it("6. Withdraw ERC20 List", async function () {
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
