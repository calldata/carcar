import { ethers } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { CarCarToken__factory } from "../typechain";

chai.use(solidity);
const { expect } = chai;

describe("CarCarToken", () => {
  let tokenAddress: string;

  beforeEach(async () => {
    const [deployer] = await ethers.getSigners();
    const tokenFactory = new CarCarToken__factory(deployer);
    const tokenContract = await tokenFactory.deploy();
    tokenAddress = tokenContract.address;
  });

  describe("Car Car Token", async () => {
    it("total supply", async () => {
      const [deployer] = await ethers.getSigners();
      const tokenInstance = new CarCarToken__factory(deployer).attach(tokenAddress);
      const totalSupply = await tokenInstance.totalSupply();

      const oneEth = ethers.utils.parseEther("1");
      expect(totalSupply.toString()).to.eq(ethers.BigNumber.from(10).pow(11).mul(oneEth));
    })
  })
  describe("Transfer", async () => {
    it("Should transfer tokens between users", async () => {
      const [deployer, sender, receiver] = await ethers.getSigners();
      const deployerInstance = new CarCarToken__factory(deployer).attach(tokenAddress);
      const toMint = ethers.utils.parseEther("1");

      await deployerInstance.mint(sender.address, toMint);
      expect(await deployerInstance.balanceOf(sender.address)).to.eq(toMint);

      const senderInstance = new CarCarToken__factory(sender).attach(tokenAddress);
      const toSend = ethers.utils.parseEther("0.4");
      await senderInstance.transfer(receiver.address, toSend);

      expect(await senderInstance.balanceOf(receiver.address)).to.eq(toSend);
    });

    it("Should fail to transfer with low balance", async () => {
      const [deployer, sender, receiver] = await ethers.getSigners();
      const deployerInstance = new CarCarToken__factory(deployer).attach(tokenAddress);
      const toMint = ethers.utils.parseEther("1");

      await deployerInstance.mint(sender.address, toMint);
      expect(await deployerInstance.balanceOf(sender.address)).to.eq(toMint);

      const senderInstance = new CarCarToken__factory(sender).attach(tokenAddress);
      const toSend = ethers.utils.parseEther("1.1");

      // Notice await is on the expect
      await expect(senderInstance.transfer(receiver.address, toSend)).to.be.revertedWith(
        "transfer amount exceeds balance",
      );
    });
  });
});
