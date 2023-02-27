// MANUALLY
//npx hardhat run scripts/deploy.js --network BSCTestnet 
//npx hardhat verify --network BSCTestnet

const { ethers } = require("hardhat");

async function setFactory(){
  const C = await ethers.getContractFactory("Factory");
  const c = await C.deploy();
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
  verify(f.address, []);
}
  
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });