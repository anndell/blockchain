const { expect } = require("chai");
const { ethers } = require("hardhat");

async function setShares(da){
    const Contract = await ethers.getContractFactory("Anndell");
    const contract = await Contract.deploy();
    await contract.deployed();
    return contract;
  }


describe("Anndell", function () {
    it("first test", async function () {
        const [owner, one, two, three] = await ethers.getSigners();
        let shares = await setShares(owner);
        console.log(shares.address);
    });
  });