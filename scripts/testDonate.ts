import { ethers,network,artifacts } from "hardhat";

async function main() {
  const [admin, user] = await ethers.getSigners();
  const Address = "0xbdEA24f8657eC8AD679b8bCcc761EcEE9600667e";
  const factory = await ethers.getContractFactory("Donate3");
  const Donate3 = await factory.attach(Address);

 // const amountIn = ethers.utils.parseEther("0.01");
  const amountIn = 1n * 10n ** 16n;
  console.log(amountIn);
  const proof = [];
  const pidInit = 123456;
  const ownerAddress = "0x2a3779072440bc6dEb94E89Ba44AB28f7b84FF1c";
  const text = "Hello, world test donate!";
  const utf8Bytes = Buffer.from(text, 'utf-8');

  await Donate3.connect(admin).donateToken(
    pidInit,
    amountIn,
    ownerAddress,
    //ethers.utils.toUtf8Bytes("Hello donate3"),
    utf8Bytes,
    proof,
    {
      value: amountIn,
    },
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
