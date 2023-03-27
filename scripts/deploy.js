// MANUALLY
//npx hardhat run scripts/deploy.js --network BSCTestnet 
//npx hardhat verify --network BSCTestnet

const { ethers } = require("hardhat");

async function main() {
  // const C = await ethers.getContractFactory("Anndell");
  // const c = await C.deploy();
  // await c.deployed();
  // console.log(c.address, "Anndell base contract address");

  // const F = await ethers.getContractFactory("Factory");
  // const f = await F.deploy("0x41977ac8ca3fcaec02094587e411afe900704277", "0x427663aeb027e7A804F4bD53416A3C3E494D618B");
  // await f.deployed();
  // console.log(f.address, "Minimal Proxy Anndell Factory contract address");

  // const Cs = await ethers.getContractFactory("AnndellSplit");
  // const cs = await Cs.deploy();
  // await cs.deployed();
  // console.log(cs.address, "AnndellSplit base contract address");

  const Fs = await ethers.getContractFactory("SplitFactory");
  const fs = await Fs.deploy("0x41977ac8ca3fcaec02094587e411afe900704277", "0xA22aCCc021F86635C07b966b776CEf9111A68D32", "0x9799dc6BBe291024A5f94ab522B7ef3791e47f72");
  await fs.deployed();
  console.log(fs.address, "Minimal Proxy AnndellSplit Factory contract address");

}
  
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

  // npx hardhat run scripts/deploy.js --network BSCTestnet
  // npx hardhat verify --network BSCTestnet contractAddress paramaters

  // Anndell base 0x427663aeb027e7A804F4bD53416A3C3E494D618B
  // anndellfee 0x41977ac8ca3fcaec02094587e411afe900704277
  // mee 0x46ef7dbabffcd0d24bb7185836774ce8550834f2