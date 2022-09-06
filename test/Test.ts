import { time, loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { BigNumber } from '@ethersproject/bignumber';
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
      bluejayTokenTest.address,
      eBLU.address
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
        ethers.utils.parseUnits('1', 23) // 1 million bluejaytokentest * 18 decimals
      );
    });
    // it("Should set the right owner", async function () {
    //   const { lock, owner } = await loadFixture(deployOneYearLockFixture);

    //   expect(await lock.owner()).to.equal(owner.address);
    // });

    // it("Should receive and store the funds to lock", async function () {
    //   const { lock, lockedAmount } = await loadFixture(
    //     deployOneYearLockFixture
    //   );

    //   expect(await ethers.provider.getBalance(lock.address)).to.equal(
    //     lockedAmount
    //   );
    // });

    // it("Should fail if the unlockTime is not in the future", async function () {
    //   // We don't use the fixture here because we want a different deployment
    //   const latestTime = await time.latest();
    //   const Lock = await ethers.getContractFactory("Lock");
    //   await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
    //     "Unlock time should be in the future"
    //   );
    // });
  });

  // describe('Withdrawals', function () {
  //   describe('Validations', function () {
  //     it('Should revert with the right error if called too soon', async function () {
  //       const { lock } = await loadFixture(deployOneYearLockFixture);

  //       await expect(lock.withdraw()).to.be.revertedWith(
  //         "You can't withdraw yet"
  //       );
  //     });

  //     it('Should revert with the right error if called from another account', async function () {
  //       const { lock, unlockTime, otherAccount } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       // We can increase the time in Hardhat Network
  //       await time.increaseTo(unlockTime);

  //       // We use lock.connect() to send a transaction from another account
  //       await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
  //         "You aren't the owner"
  //       );
  //     });

  //     it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
  //       const { lock, unlockTime } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       // Transactions are sent using the first signer by default
  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).not.to.be.reverted;
  //     });
  //   });

  //   describe('Events', function () {
  //     it('Should emit an event on withdrawals', async function () {
  //       const { lock, unlockTime, lockedAmount } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw())
  //         .to.emit(lock, 'Withdrawal')
  //         .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
  //     });
  //   });

  //   describe('Transfers', function () {
  //     it('Should transfer the funds to the owner', async function () {
  //       const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).to.changeEtherBalances(
  //         [owner, lock],
  //         [lockedAmount, -lockedAmount]
  //       );
  //     });
  //   });
  // });
});
