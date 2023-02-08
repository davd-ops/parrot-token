import { BigNumber, Signer } from "ethers";
import {ParrotRewards } from "../typechain-types/index";
import ParrotRewardsArtifact from "../artifacts/contracts/ParrotRewards.sol/ParrotRewards.json";
import { MockUSDC } from "../typechain-types/index";
import MockUSDCArtifact from "../artifacts/contracts/MockUSDC.sol/MockUSDC.json";
import { ethers, waffle } from "hardhat";
import chai from "chai";
import chaiAsPromised from "chai-as-promised";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

const { deployContract } = waffle;
const { expect } = chai;
chai.use(chaiAsPromised);
let user: SignerWithAddress;
let contractOwner: SignerWithAddress;
let random: SignerWithAddress;
let ParrotRewards: ParrotRewards;
let MockUSDC: MockUSDC;
const oneUSDC = 10 ** 6;

describe("Initialization of core functions", function () {
  beforeEach(async function () {
    [contractOwner, user, random] = await ethers.getSigners();

    ParrotRewards = (await deployContract(
      contractOwner,
      ParrotRewardsArtifact,
      [contractOwner.address]
    )) as ParrotRewards;

    MockUSDC = (await deployContract(
      contractOwner,
      MockUSDCArtifact
    )) as MockUSDC;
    });

    describe("USDC Contract", function () {
      describe("General Stuff", function () {
        it("should have proper name", async function () {
          expect(await MockUSDC.name()).to.equal("USD Coin");
        });
        it("should have proper symbol", async function () {
          expect(await MockUSDC.symbol()).to.equal("USDC");
        });
        it("should mint some USDC", async function () {
          await expect(MockUSDC.connect(contractOwner).mint(contractOwner.address, oneUSDC))
            .to.be.fulfilled;
          expect(await MockUSDC.balanceOf(contractOwner.address)).to.equal(oneUSDC);
        });
      });
    });

  describe("Parrot Rewards Contract", function () {
    beforeEach(async function () {
      await expect(MockUSDC.connect(contractOwner).mint(contractOwner.address, oneUSDC))
            .to.be.fulfilled;
            await expect(MockUSDC.connect(contractOwner).approve(ParrotRewards.address, oneUSDC))
            .to.be.fulfilled;
      });
    describe("General Stuff", function () {
      it("should have proper owner", async function () {
        expect(await ParrotRewards.owner()).to.equal(contractOwner.address);
      });
    });
  });
  describe("Deposit", function () {
    it("should allow a user to deposit the correct amount of shares", async function () {
    const depositAmount = oneUSDC;
    await expect(ParrotRewards.connect(contractOwner).deposit(depositAmount))
    .to.be.fulfilled;
    expect(await ParrotRewards.shares(user.address)).to.equal(depositAmount);
    expect(await ParrotRewards.totalSharesDeposited()).to.equal(depositAmount);
    });
    it("should decrease the user's balance by the amount deposited", async function () {
      const depositAmount = oneUSDC;
      const userInitialBalance = await MockUSDC.balanceOf(user.address);
      await expect(ParrotRewards.connect(contractOwner).deposit(depositAmount))
    .to.be.fulfilled;
      expect(await MockUSDC.balanceOf(contractOwner.address)).to.equal(userInitialBalance.sub(depositAmount));
    });
      
    it("should emit the DepositRewards event", async function () {
      const depositAmount = oneUSDC;
      const { events } = await expect(MockUSDC.connect(user).transfer(ParrotRewards.address, depositAmount))
        .to.be.fulfilled;
      expect(events).to.have.property("DepositRewards");
      const depositEvent = events.DepositRewards.find(
        (event: { args: { wallet: string; amountETH: BigNumber } }) =>
          event.args.wallet === user.address &&
          event.args.amountETH.eq(depositAmount)
      );
      expect(depositEvent).to.not.be.undefined;
    });
  });
});
