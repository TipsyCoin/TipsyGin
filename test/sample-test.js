const { expect } = require('chai')
const { ethers } = require('hardhat')

describe('TokenTimeLock Contract Tests', () => {
    let deployer;
    let account1;
    let account2;
    let tipsyCoinMock;
    let ninetyDays;
    let sevenDays;
    let oneDay;
    let tipsyPower; //10e18
    let defaultMintTo;
    let silverAmount;
    let goldAmount;

    beforeEach(async () => {
        [deployer, keeper, eoa] = await ethers.getSigners();
        let TipsyGin = await ethers.getContractFactory('Gin');
        TipsyGin = await TipsyGin.connect(deployer);
        tipsyGin = await TipsyGin.deploy();
        await tipsyGin.deployed();

        await tipsyGin.initialize(deployer.address, keeper.address);

    })

    describe('Testing for Tipsy Gin', async () => {

        it('Permit/Revoke Contract tests', async () => {

          const Greeter = await ethers.getContractFactory("Greeter"); //Fake contract address
          const greeter = await Greeter.deploy("Hello, world!");
          
          await expect(tipsyGin.connect(deployer).permitContract(eoa.address)).to.be.revertedWith("Contract Minter must be a contract");

          await expect(tipsyGin.connect(eoa).permitContract(greeter.address)).to.be.revertedWith("TipsyOwnable: caller is not the owner");
          
          await expect(tipsyGin.connect(keeper).permitContract(greeter.address)).to.be.revertedWith("TipsyOwnable: caller is not the owner");
          
          await tipsyGin.connect(deployer).permitContract(greeter.address);

          await expect(tipsyGin.connect(eoa).revokeContract(greeter.address)).to.be.revertedWith("TipsyOwnable: caller is not the owner");
          
          await tipsyGin.connect(keeper).revokeContract(greeter.address);
        });

        it('Permit/Revoke Signer tests', async () => {

          const Greeter = await ethers.getContractFactory("Greeter"); //Fake contract address
          const greeter = await Greeter.deploy("Hello, world!");
          
          await expect(tipsyGin.connect(deployer).permitSigner(greeter.address)).to.be.revertedWith("Direct Signer must be an EOA");

          await expect(tipsyGin.connect(eoa).permitSigner(eoa.address)).to.be.revertedWith("TipsyOwnable: caller is not the owner");
          
          await expect(tipsyGin.connect(keeper).permitContract(eoa.address)).to.be.revertedWith("TipsyOwnable: caller is not the owner");
          
          await tipsyGin.connect(deployer).permitSigner(eoa.address);

          await expect(tipsyGin.connect(eoa).revokeSigner(eoa.address)).to.be.revertedWith("TipsyOwnable: caller is not the owner");
          
          await tipsyGin.connect(keeper).revokeSigner(eoa.address);
        });

        it('setRequiredSigs tests', async () => {

          await expect(tipsyGin.connect(eoa).setRequiredSigs(2)).to.be.revertedWith("TipsyOwnable: caller is not the owner");
          
          await expect(tipsyGin.connect(deployer).setRequiredSigs(1)).to.be.revertedWith("SIGS_BELOW_MINIMUM");
          
          await tipsyGin.connect(deployer).setRequiredSigs(3);

          await tipsyGin.connect(deployer).setRequiredSigs(2);

        });

        it('pause tests', async () => {

          await expect(tipsyGin.connect(eoa).setPause(true)).to.be.revertedWith("TipsyOwnable: caller is not the owner");
        
          await tipsyGin.connect(deployer).setPause(true);

          await tipsyGin.connect(deployer).setPause(false);
          
        });




        

    });
});