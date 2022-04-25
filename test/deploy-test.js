const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LG", function () {
  it("Should initially have 0 supply", async function () {
    const multisig = '0x167975F759e9fC3C5f176Aa7648Bc89FD510c410';
    const LG = await ethers.getContractFactory("LG");
    const lg = await LG.deploy(multisig, "ipfs://QmboBADQ1G8gRe42fQzXoLeYvNj2D78xfB2nwx4swkyYf2/{id}.json");
    await lg.deployed();

    //expect(await greeter.greet()).to.equal("Hello, world!");
    //const setGreetingTx = await greeter.setGreeting("Hola, mundo!");
    //
    // wait until the transaction is mined
    //await setGreetingTx.wait();
    //expect(await greeter.greet()).to.equal("Hola, mundo!");
    expect(await lg.functions.totalSupply.call()).to.equal(0);
  });
});
