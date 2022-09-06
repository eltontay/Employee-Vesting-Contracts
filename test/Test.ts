import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
describe('Lock', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearLockFixture() {
    // Contracts are deployed using the first signer/account by default
    const [oracle, em1, em2, em3] = await ethers.getSigners();

    // Deploying proxy bluejay token
    const BluejayTokenTest = await ethers.getContractFactory(
      'BluejayTokenTest'
    );
    const bluejayTokenTest = await BluejayTokenTest.deploy();

    // Deploying eBLU token
    const EBLU = await ethers.getContractFactory('EBLU');
    const eBLU = await EBLU.deploy();

    // Deploying Vesting Smart Contract
    const Vesting = await ethers.getContractFactory('Vesting');
    const vesting = await Vesting.deploy(
      eBLU.address,
      bluejayTokenTest.address
    );

    return { oracle, em1, em2, em3, bluejayTokenTest, eBLU, vesting };
  }

  describe('Check BluejayTokenTest Initialisation', function () {
    it('BluejayTokenTest should be initialised', async function () {
      const { bluejayTokenTest } = await loadFixture(deployOneYearLockFixture);

      await bluejayTokenTest.initialize();

      expect(await bluejayTokenTest.totalSupply()).to.equal(
        ethers.utils.parseUnits('1', 24) // 1 million bluejaytokentest * 18 decimals
      );
    });

    it('Check BluejayTokenTest Minting', async function () {
      const { bluejayTokenTest, oracle, vesting } = await loadFixture(
        deployOneYearLockFixture
      );

      await bluejayTokenTest.initialize();

      await bluejayTokenTest.grantRole(
        '0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6',
        oracle.address
      );

      await bluejayTokenTest.mint(
        vesting.address,
        ethers.utils.parseUnits('1', 23)
      ); // sending to Vesting contract 100,000 BLU

      expect(await bluejayTokenTest.balanceOf(vesting.address)).to.equal(
        ethers.utils.parseUnits('1', 23)
      );
    });
  });

  describe('Check EBLU Initialisation', function () {
    it('EBLU should be initialised', async function () {
      const { eBLU } = await loadFixture(deployOneYearLockFixture);

      await eBLU.initialize();

      expect(await eBLU.name()).to.equal('eBLU');
    });

    it('Check EBLU Minting', async function () {
      const { eBLU, em1, oracle, vesting } = await loadFixture(
        deployOneYearLockFixture
      );

      await eBLU.initialize();

      await eBLU.mint(em1.address, ethers.utils.parseUnits('1', 23)); // sending to employee1 100,000 eBLU

      expect(await eBLU.balanceOf(em1.address)).to.equal(
        ethers.utils.parseUnits('1', 23)
      );
    });
  });

  describe('Check Vesting', function () {
    it('Check Creation of Vesting Schedule', async function () {
      const { bluejayTokenTest, vesting, eBLU, oracle, em1 } =
        await loadFixture(deployOneYearLockFixture);

      // Test 1 for bluejaytoken initialisation

      await bluejayTokenTest.initialize();

      await bluejayTokenTest.grantRole(
        '0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6',
        oracle.address
      );

      await bluejayTokenTest.mint(
        vesting.address,
        ethers.utils.parseUnits('1', 23)
      ); // sending to Vesting contract 100,000 BLU

      // Test 2 for eblu initialisation

      await eBLU.initialize();

      await eBLU.mint(em1.address, ethers.utils.parseUnits('1', 23)); // sending to employee1 100,000 eBLU

      // Vesting testing creating schedule
      await vesting.createVestingSchedule(
        em1.address,
        true,
        ethers.utils.parseUnits('1', 23)
      );
    });

    it('Check Correct Vesting Amount', async function () {
      const { bluejayTokenTest, vesting, eBLU, oracle, em1 } =
        await loadFixture(deployOneYearLockFixture);

      // Test 1 for bluejaytoken initialisation

      await bluejayTokenTest.initialize();

      await bluejayTokenTest.grantRole(
        '0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6',
        oracle.address
      );

      await bluejayTokenTest.mint(
        vesting.address,
        ethers.utils.parseUnits('1', 23)
      ); // sending to Vesting contract 100,000 BLU

      // Test 2 for eblu initialisation

      await eBLU.initialize();

      await eBLU.mint(em1.address, ethers.utils.parseUnits('1', 23)); // sending to employee1 100,000 eBLU

      // Vesting testing creating schedule
      await vesting.createVestingSchedule(
        em1.address,
        true,
        ethers.utils.parseUnits('1', 23)
      );

      const id = await vesting.computeVestingScheduleIdForAddressAndIndex(
        em1.address,
        0
      );

      expect(await vesting.computeRedemptionAmount(id)).to.equal(
        ethers.utils.parseUnits('1', 21) // 1k BLU able to redeem
      );
    });

    it('Check Redemption', async function () {
      const { bluejayTokenTest, vesting, eBLU, oracle, em1 } =
        await loadFixture(deployOneYearLockFixture);

      // Test 1 for bluejaytoken initialisation

      await bluejayTokenTest.initialize();

      await bluejayTokenTest.grantRole(
        '0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6',
        oracle.address
      );

      await bluejayTokenTest.mint(
        vesting.address,
        ethers.utils.parseUnits('1', 23)
      ); // sending to Vesting contract 100,000 BLU

      // Test 2 for eblu initialisation

      await eBLU.initialize();

      await eBLU.mint(em1.address, ethers.utils.parseUnits('1', 23)); // sending to employee1 100,000 eBLU

      // Vesting testing creating schedule
      await vesting.createVestingSchedule(
        em1.address,
        true,
        ethers.utils.parseUnits('1', 23)
      );

      await expect(vesting.redeem(em1.address))
        .to.emit(vesting, 'Redeemed')
        .withArgs(em1.address, ethers.utils.parseUnits('1', 21));
    });
  });
});
