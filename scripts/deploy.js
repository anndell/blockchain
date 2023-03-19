// MANUALLY
//npx hardhat run scripts/deploy.js --network BSCTestnet 
//npx hardhat verify --network BSCTestnet

const { ethers } = require("hardhat");

async function setFactory(){
  const C = await ethers.getContractFactory("Factory");
  const c = await C.deploy("0x41977ac8CA3FcaEC02094587e411AFE900704277");
  await c.deployed();
  return c;
}

async function setAnndellFee(){
  const C = await ethers.getContractFactory("AnndellFee");
  const c = await C.deploy("0x46Ef7DbABFfcd0d24Bb7185836774Ce8550834f2", "0x5FC6eBb13C9B5F0dFc27800fEdd53465Bd5FdEb2");
  await c.deployed();
  return c;
}

async function verify(contract, arr){
  try {
    await ethers.run("verify:verify", {address: contract ,constructorArguments: arr});
  } catch (error) {
    if (error.message.includes("Reason: Already Verified")) {
        console.log(contract.address, " contract is already verified!");
    }
  }
}
  
async function main() {
  const f = await setFactory();
  console.log(f.address);
  // await verify(f.address, ["0x46Ef7DbABFfcd0d24Bb7185836774Ce8550834f2", "0x5FC6eBb13C9B5F0dFc27800fEdd53465Bd5FdEb2"]);
}
  
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

  // npx hardhat run scripts/deploy.js --network BSCTestnet
  // npx hardhat verify --network BSCTestnet contractAddress paramaters