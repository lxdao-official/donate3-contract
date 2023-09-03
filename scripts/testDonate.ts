import { ethers,network,artifacts } from "hardhat";

async function main() {
  const [admin, user] = await ethers.getSigners();
  const Address = "0xf1f5219C777E44BCd2c2C43b6aCe2458169c0579";
  const factory = await ethers.getContractFactory("Donate3");
  const Donate3 = await factory.attach(Address);

 // const amountIn = ethers.utils.parseEther("0.01");
  const amountIn = 1n * 10n ** 16n;
  console.log(amountIn);
  const proof = [];
  const pidInit = 123456;
  const donnerAddress = "0x57123a01dB689c7B0fD79CB136da065b75b42F7b";
  const text = "Hello, world test donate!";
  const utf8Bytes = Buffer.from(text, 'utf-8');
  
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
  await Donate3.connect(admin).donate(
    ZERO_ADDRESS,
    amountIn,
    ZERO_ADDRESS,
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
