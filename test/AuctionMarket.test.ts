import { ethers } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";

chai.use(solidity);
const { expect } = chai;

describe("Test AuctionMarket", () => {
    let carcarNftContract: any;
    let auctionMarketContract: any;
    let carcarTokenContract: any;

    beforeEach(async () => {
        const [deployer, u1, u2] = await ethers.getSigners();
        const carcarTokenFactory = await ethers.getContractFactory("CarCarToken");
        carcarTokenContract =  await carcarTokenFactory.deploy();

        const carcarNftFactory = await ethers.getContractFactory("CarCarNft");
        carcarNftContract = await carcarNftFactory.deploy();

        const auctionMarketFactory = await ethers.getContractFactory("AuctionMarket");
        auctionMarketContract = await auctionMarketFactory.deploy(carcarTokenContract.address, carcarNftContract.address);
    });

    describe("Auction market", () => {
        it("test trading", async () => {
            const [owner, u1, u2] = await ethers.getSigners();
            // owner transfer 10 token 0 to u1
            await carcarNftContract.safeTransferFrom(owner.address, u1.address, 0, 10, "0x00");
            // change signer to u1
            carcarNftContract = carcarNftContract.connect(u1);
            // u1 approve to auctionMarketContract
            await carcarNftContract.setApprovalForAll(auctionMarketContract.address, true);

            // change signer to u1
            auctionMarketContract =  auctionMarketContract.connect(u1)
            // u1 sell 10 tokens with tokenId 0
            const tx = await auctionMarketContract.sellItem(0, 500, 10);

            const txRecipit = await tx.wait();
            const auctionId = txRecipit.logs[0].topics[1];
            const auction = await auctionMarketContract.getAuctionItem(auctionId);
            const expectedId = await auctionMarketContract.calcItemAuctionId(auction);
            expect(auctionId == expectedId);

            // transfer 5000 cct to u2
            await carcarTokenContract.transfer(u2.address, 5000);

            // approve u2 to auctionMarketContract 
            carcarTokenContract = carcarTokenContract.connect(u2);
            carcarTokenContract.approve(auctionMarketContract.address, 5000);

            // change signer to u2
            auctionMarketContract = auctionMarketContract.connect(u2);

            // u2 buy 10 tokens of tokenId 0 with 5000 cct
            await auctionMarketContract.purchase(auctionId, 10);

            expect(carcarTokenContract.balanceOf(u2.address) == 0, "u2 cct should be zero");
            expect(carcarNftContract.balanceOf(u1.address, 0) == 0, "u1 has zero token of tokenId 0");
            expect(carcarNftContract.balanceOf(u2.address, 0) == 10, "u2 should have 10 tokens of tokenId 0");

            expect(carcarTokenContract.balanceOf(u1.address) == 5000 * 99 / 100, "unexpected u1 cct balance");
            expect(carcarTokenContract.balanceOf(auctionMarketContract.address) == 5000 / 100, "unexpected auctionMarketContract balance");
        })
    })
})
