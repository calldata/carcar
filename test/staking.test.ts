import { ethers } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { Staking__factory } from "../typechain";

chai.use(solidity);
const { expect } = chai;

describe("Staking", () => {
    let stakeContract: any;
    let cctContract: any;

    beforeEach(async () => {
        const [deployer] = await ethers.getSigners();
        const cctFactory = await ethers.getContractFactory("CarCarToken");
        cctContract = await cctFactory.deploy();

        const stakeFactory = await ethers.getContractFactory("Staking");
        stakeContract = await stakeFactory.deploy(cctContract.address);
    });
    
    describe("Test staking", () => {
        it("test createNewStrategy", async () => {
            const tx = await stakeContract.createNewStrategy(1000, 3600, cctContract.address);
            expect(tx).to.emit(stakeContract, "CreateNewStrategy").withArgs(1000, 3600, cctContract.address);
        })

        it("test stake", async () => {
            const [deployer, staker] = await ethers.getSigners();

            await stakeContract.createNewStrategy(1000, 3600, cctContract.address);
            await cctContract.transfer(staker.address, 1000);

            cctContract = cctContract.connect(staker);
            await cctContract.approve(stakeContract.address, 1000);

            const strategyId = await stakeContract.calcStrategyId(1000, 3600, cctContract.address);

            stakeContract = stakeContract.connect(staker);

            const tx = await stakeContract.stake(strategyId);
            expect(tx).to.emit(stakeContract, "CreateNewStaking");
        })

        it("test early unstake", async () => {
            const [deployer, staker] = await ethers.getSigners();

            await stakeContract.createNewStrategy(1000, 3600, cctContract.address);
            await cctContract.transfer(staker.address, 1000);

            cctContract = cctContract.connect(staker);
            await cctContract.approve(stakeContract.address, 1000);

            const strategyId = await stakeContract.calcStrategyId(1000, 3600, cctContract.address);

            stakeContract = stakeContract.connect(staker);

            const tx = await stakeContract.stake(strategyId);
            const txRecipt = await tx.wait();
            const startAt = ethers.BigNumber.from(txRecipt.events[2].data);
            const stakingId = await stakeContract.calcStakingId(staker.address, strategyId, startAt);
            
            const tx2 = stakeContract.unstake(stakingId);
            expect(tx2).to.emit(stakeContract,  "EarlyUnstake").withArgs(staker.address, stakingId);
        })

        it("test unstake", async () => {
            const [deployer, staker] = await ethers.getSigners();

            await stakeContract.createNewStrategy(1000, 3600, cctContract.address);
            await cctContract.transfer(staker.address, 1000);

            cctContract = cctContract.connect(staker);
            await cctContract.approve(stakeContract.address, 1000);

            const strategyId = await stakeContract.calcStrategyId(1000, 3600, cctContract.address);

            stakeContract = stakeContract.connect(staker);

            const tx = await stakeContract.stake(strategyId);
            const txRecipt = await tx.wait();
            const startAt = ethers.BigNumber.from(txRecipt.events[2].data);
            const stakingId = await stakeContract.calcStakingId(staker.address, strategyId, startAt);

            await ethers.provider.send("evm_increaseTime", [3601]);

            const tx2 = stakeContract.unstake(stakingId);
            expect(tx2).to.emit(stakeContract,  "StakingFinished").withArgs(staker.address, stakingId);
        })
    })
})