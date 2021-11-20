import { ethers } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";

chai.use(solidity);
const { expect } = chai;

describe("CarCarGameLogic", () => {
    let carCarGameLogicContract: any;
    let carcarNftContract: any;
    let carcarTokenContract: any;

    beforeEach(async () => {
        const [deplyer, carRepairFeeWallet] = await ethers.getSigners();

        const carcarTokenFactory = await ethers.getContractFactory("CarCarToken");
        carcarTokenContract = await carcarTokenFactory.deploy();

        const carcarNftFactory = await ethers.getContractFactory("CarCarNft");
        carcarNftContract = await carcarNftFactory.deploy();

        const CarCarGameLogicFactory = await ethers.getContractFactory("CarCarGameLogic");
        carCarGameLogicContract = await CarCarGameLogicFactory.deploy(carcarNftContract.address, carcarTokenContract.address, carRepairFeeWallet.address, deplyer.address);
    })

    describe("Play Game", () => {
        it("test enter game", async () => {
            const [deplyer, _carRepairFeeWallet, player] = await ethers.getSigners();
            // transfer a car to player
            await carcarNftContract.safeTransferFrom(deplyer.address, player.address, 0, 1, "0x00");

            // approve player nft to carCarGameLogicContract
            carcarNftContract = carcarNftContract.connect(player);
            await carcarNftContract.setApprovalForAll(carCarGameLogicContract.address, true);

            // change signer
            carCarGameLogicContract = carCarGameLogicContract.connect(player);

            // enter game
            const tx = await carCarGameLogicContract.enterGame(0);
            // enter game should trigger an event
            expect(tx).to.emit(carCarGameLogicContract, "PlayerEnterGame").withArgs(player.address);

            const cars = await carcarNftContract.balanceOf(player.address, 0);
            expect(cars == 0, "car should be locked in carCarGameLogicContract");
        })

        it("test exit game without car broken", async () => {
            const [deplyer, _carRepairFeeWallet, player] = await ethers.getSigners();
            // transfer a car to player
            await carcarNftContract.safeTransferFrom(deplyer.address, player.address, 0, 1, "0x00");

            // approve player nft to carCarGameLogicContract
            carcarNftContract = carcarNftContract.connect(player);
            await carcarNftContract.setApprovalForAll(carCarGameLogicContract.address, true);

            // change signer
            carCarGameLogicContract = carCarGameLogicContract.connect(player);

            // enter game
            await carCarGameLogicContract.enterGame(0);
            // exit game
            const tx = await carCarGameLogicContract.exitGame(0);
            // exit game should trigger an event
            expect(tx).to.emit(carCarGameLogicContract, "PlayerExitGame").withArgs(player.address);

            // player's car got back
            const cars = await carcarNftContract.balanceOf(player.address, 0);
            expect(cars == 1, "player's car should give back");
        })

        it("test exit game fail when car is broken", async () => {
            const [deplyer, _carRepairFeeWallet, player] = await ethers.getSigners();
            // transfer a car to player
            await carcarNftContract.safeTransferFrom(deplyer.address, player.address, 0, 1, "0x00");

            // approve player nft to carCarGameLogicContract
            carcarNftContract = carcarNftContract.connect(player);
            await carcarNftContract.setApprovalForAll(carCarGameLogicContract.address, true);

            // change signer
            carCarGameLogicContract = carCarGameLogicContract.connect(player);

            // enter game
            await carCarGameLogicContract.enterGame(0);

            carCarGameLogicContract = carCarGameLogicContract.connect(deplyer);
            // set player's car broken
            const tx1 = await carCarGameLogicContract.setCarBroken(player.address, 0);
            expect(tx1).to.emit(carCarGameLogicContract, "PlayerCarBroken").withArgs(player.address);

            // player exit game fail
            carCarGameLogicContract = carCarGameLogicContract.connect(player);
            await expect(carCarGameLogicContract.exitGame(0)).to.revertedWith("Player car is broken");
        })

        it("test when car repaired player can exitGame", async () => {
            const [deplyer, carRepairFeeWallet, player] = await ethers.getSigners();
            // transfer a car to player
            await carcarNftContract.safeTransferFrom(deplyer.address, player.address, 0, 1, "0x00");

            // transfer 10000 cct to player to repair broken car
            await carcarTokenContract.transfer(player.address, 10000);

            // change carcarTokenContract signer
            carcarTokenContract = carcarTokenContract.connect(player);

            // approve carCarGameLogicContract to spend player cct token
            await carcarTokenContract.approve(carCarGameLogicContract.address, 10000);

            // approve player nft to carCarGameLogicContract
            carcarNftContract = carcarNftContract.connect(player);
            await carcarNftContract.setApprovalForAll(carCarGameLogicContract.address, true);

            // change signer
            carCarGameLogicContract = carCarGameLogicContract.connect(player);

            // enter game
            await carCarGameLogicContract.enterGame(0);

            carCarGameLogicContract = carCarGameLogicContract.connect(deplyer);
            // set player's car broken
            const tx1 = await carCarGameLogicContract.setCarBroken(player.address, 0);
            expect(tx1).to.emit(carCarGameLogicContract, "PlayerCarBroken").withArgs(player.address);

            // change signer
            carCarGameLogicContract = carCarGameLogicContract.connect(player);

            // player repair broken car
            await expect(carCarGameLogicContract.repair(0)).to.emit(carCarGameLogicContract, "CarRepaired").withArgs(player.address, 0);

            // player cct token is 0
            expect(await carcarTokenContract.balanceOf(player.address)).to.eq(0);

            // carRepairFeeWallet balance is 5000
            expect(await carcarTokenContract.balanceOf(carRepairFeeWallet.address)).to.eq(5000);

            // player can exit game now
            await expect(carCarGameLogicContract.exitGame(0)).to.emit(carCarGameLogicContract, "PlayerExitGame").withArgs(player.address);
        })
    })

    describe("Player rewards", () => {
        it("test giveAwayWinnerFragment", async () => {
            const [deplyer, carRepairFeeWallet, player] = await ethers.getSigners();
            await carcarNftContract.setMinter(carCarGameLogicContract.address);

            // give away 10 winner fragment to player
            await carCarGameLogicContract.giveAwayWinnerFragment(player.address, 10);
            expect(await carcarNftContract.balanceOf(player.address, 5)).to.eq(10);
        })

        it("test claimWinnerBlindBox", async () => {
            const [deplyer, carRepairFeeWallet, player] = await ethers.getSigners();
            await carcarNftContract.setMinter(carCarGameLogicContract.address);

            // give away 10 winner fragment to player
            await carCarGameLogicContract.giveAwayWinnerFragment(player.address, 10);
            expect(await carcarNftContract.balanceOf(player.address, 5)).to.eq(10);

            //  change signer
            carCarGameLogicContract = carCarGameLogicContract.connect(player);

            // use 10 winner fragments to mint 1 winner box
            await carCarGameLogicContract.claimWinnerBlindBox();
            // player has 1 winner box
            expect(await carcarNftContract.balanceOf(player.address, 6)).to.eq(1);
            // player's 10 winner fragments destroyed
            expect(await carcarNftContract.balanceOf(player.address, 5)).to.eq(0);
        })

        it("test player open blind box", async () => {
            const [deplyer, carRepairFeeWallet, player] = await ethers.getSigners();
            await carcarNftContract.setMinter(carCarGameLogicContract.address);

            // give away 10 winner fragment to player
            await carCarGameLogicContract.giveAwayWinnerFragment(player.address, 10);
            expect(await carcarNftContract.balanceOf(player.address, 5)).to.eq(10);

            //  change signer
            carCarGameLogicContract = carCarGameLogicContract.connect(player);

            // use 10 winner fragments to mint 1 winner box
            await carCarGameLogicContract.claimWinnerBlindBox();
            // player has 1 winner box
            expect(await carcarNftContract.balanceOf(player.address, 6)).to.eq(1);
            // player's 10 winner fragments destroyed
            expect(await carcarNftContract.balanceOf(player.address, 5)).to.eq(0);

            // OpenBlindBox should be triggered
            await expect(carCarGameLogicContract.openWinnerBlindBoxRequest()).to.emit(carCarGameLogicContract, "OpenBlindBox").withArgs(player.address);

            // change singer
            carCarGameLogicContract = carCarGameLogicContract.connect(deplyer);

            await carcarNftContract.setApprovalForAll(carCarGameLogicContract.address, true);

            // deliver blind box
            await expect(carCarGameLogicContract.deliverOpenedBlindBox(player.address, 4, 1)).to.emit(carCarGameLogicContract, "BlindBoxDelivered")
                .withArgs(player.address, 4, 1);

            // player's blind box is burned after opened
            expect(await carcarNftContract.balanceOf(player.address, 6)).to.eq(0);
        })

    })
})
