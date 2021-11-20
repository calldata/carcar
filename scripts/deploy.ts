// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from 'hardhat';

async function main(): Promise<void> {
  const [deplyer, carRepairFeeWallet] = await ethers.getSigners();

  const carcarTokenFactory = await ethers.getContractFactory("CarCarToken");
  const carcarTokenContract = await carcarTokenFactory.deploy();
  console.log("deploy CarCarToken at: ", carcarTokenContract.address);

  const carcarNftFactory = await ethers.getContractFactory("CarCarNft");
  const carcarNftContract = await carcarNftFactory.deploy();
  console.log("deploy CarCarNft at: ", carcarNftContract.address);

  const auctionMarketFactory = await ethers.getContractFactory("AuctionMarket");
  const auctionMarketContract = await auctionMarketFactory.deploy(carcarTokenContract.address, carcarNftContract.address);
  console.log("deploy auctionMarketContract at: ", auctionMarketContract.address);

  const CarCarGameLogicFactory = await ethers.getContractFactory("CarCarGameLogic");
  const carCarGameLogicContract = await CarCarGameLogicFactory.deploy(carcarNftContract.address, carcarTokenContract.address, carRepairFeeWallet.address, deplyer.address);
  console.log("deploy CarCarGameLogic at: ", carCarGameLogicContract.address);

  // set minter
  await carcarNftContract.setMinter(carCarGameLogicContract.address);
  console.log("set minter done...")
  // approve CarCarGameLogic to opeerate all CarCarNft
  await carcarNftContract.setApprovalForAll(carCarGameLogicContract.address, true);
  console.log("approve nft done...")
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
