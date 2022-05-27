const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("WorkToken", function () {
  it("deploy", async function () {
    const [owner] = await ethers.getSigners();
    const WorkToken = await ethers.getContractFactory("workToken");
    const workToken = await WorkToken.deploy();
    await workToken.deployed();
    
    //expect(await greeter.greet()).to.equal("Hello, world!");

    //console.log(owner.address)
    
    const tx1 = await workToken.newProjectCreater(10, 604800, "this is a URI");
    await tx1.wait();

    const tx2 = await workToken.getProjectCreater(owner.address);
    console.log(tx2)
    /*
    // wait until the transaction is mined
    expect(await greeter.greet()).to.equal("Hola, mundo!");
    */
  });
});
