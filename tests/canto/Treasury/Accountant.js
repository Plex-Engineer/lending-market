const { ethers } = require("hardhat");
const { expect } = require("chai");
// import  {deployComptroller, deployUnitroller } from "./Utils";


const comp = "0x9b875345d8c7D9df14B68cCD251A64fCDA4A9578";
const note = "0x9747627c23e307a13E57C8185beA3879aA6f7C4E";
const wcanto = "0x3158f2bBfc31D162d508ab03B4B25229edbEc4AB";
const jumprate = "0x243446bAcc3f26eb101D003398DD7704Eeba5251";
const unitroller = "0x94160b46fdd7C65456cA886b73F17Df24e12B15F";
const treasury = "0x817EBBc6b1a060233811de8C4BdE3D5ab8c0cAee";
const cnote = "0x78dD3d1e3EaF1399351cd09b9ABAB0D3188E8D3d";
const accountant = "0xCA5C299151fBe55f9c39AD3512bc8E4483899E18";
const ccanto = "0xe9ED5A7AF26d80989e53e36E76493ccc81e31367";
const priceoracle = "0x52682a396debE63f44B25B575fcA23D871783816";
let Accountant;
let Comptroller;
let Unitroller;
let Note;
let JumpRate;
let CNote;
let Treasury;
let CCanto;
let WCanto;
let PriceOracle;

let deployer;

describe("Accountant Mechanism Tests", async function() {
    before(async () => {   
        [deployer] = await ethers.getSigners();
        Comptroller = await ethers.getContractAt("Comptroller", comp, deployer);
        Unitroller = await ethers.getContractAt("Unitroller", unitroller, deployer); 
        Note = await ethers.getContractAt("Note", note, deployer);
        CNote = await ethers.getContractAt("CNote", cnote, deployer); 
        JumpRate = await ethers.getContractAt("JumpRateModel", jumprate, deployer);
        Treasury = await ethers.getContractAt("TreasuryDelegate", treasury, deployer);
        Accountant = await ethers.getContractAt("AccountantDelegate", accountant, deployer); 
        WCanto = await ethers.getContractAt("WCanto", wcanto, deployer);
        CCanto = await ethers.getContractAt("CErc20Immutable", ccanto, deployer);
        PriceOracle = await ethers.getContractAt("SimplePriceOracle", priceoracle, deployer);
    });


    //sanity check that we are connected to the correct network, and that everything is working as it should
    it("Verify that Comptroller exists, and network is correct:)", async () => {
        expect(deployer.address).to.equal("0xC90D884AB5b4458852b2a7C3eDC8425F4d1daf27");
        const code = await ethers.provider.getCode(Comptroller.address);
        expect(code).to.not.equal("0x");
        await(await Note._setAccountantContract(Accountant.address)).wait();
    });

    //testing that both COmptroller and Unitroller are linked
    it("Link Unitroller and Comptroller", async function() {
        const txSet = await Unitroller._setPendingImplementation(Comptroller.address);
        await txSet.wait();
        expect(await Unitroller.pendingComptrollerImplementation()).to.equal(Comptroller.address);
        const txAccept  = await Comptroller._become(Unitroller.address);
        await txAccept.wait();
        expect(await Unitroller.comptrollerImplementation()).to.equal(Comptroller.address);
    }); 


    //initialize CNote Lending Market and Link with Accountant
    it("Configure Comptroller and add CNote LM", async () => {
        const txConfig = await CNote._setAccountantContract(Accountant.address);
        let res = await txConfig.wait();
        expect(await CNote.retAccountant()).to.equal(Accountant.address);
        //mint all Note to Accountant
        await (await Note._mint_to_Accounting()).wait()
        //error in MINT_TO_ACCOUNTING 
        const txOracle = await Comptroller._setPriceOracle(PriceOracle.address);
        await txOracle.wait();
        expect(await Comptroller.oracle()).to.equal(PriceOracle.address);
        //add cnote market
        const txMarket = await Comptroller._supportMarket(CNote.address);
        await txMarket.wait();
        expect((await Comptroller.getAllMarkets()).find(m =>
            m == cnote)).to.equal(cnote);
        //initialize accountant, (enter CNote Market)
        const txInit = await Accountant.initialize();
        const resp = await txInit.wait(); //obtain tx response
        //ensure that initialization does not fail
        const ev = resp.events.find(e => e.event === 'AcctInit');
        console.log(ev.args);
        expect((await Comptroller.getAssetsIn(Accountant.address)).find(m => m == cnote))
            .to.equal(cnote);
    });

    //first user flow with CLM Note Pool
    it("Test whether Accountant is entered in NLM and CANTO -> wCANTO flow", async () => {
        //sanity check that accountant has entered Note LM
        expect(await Comptroller.checkMembership(Accountant.address, CNote.address)).to.be.true;
        //deployer deposits 1000canto for 1000wcanto?
        const priorBalance = await WCanto.balanceOf(deployer.address);
        let tx = await WCanto.deposit({value: 1000});
        await tx.wait();
        expect((await WCanto.balanceOf(deployer.address)) - priorBalance).to.equal(1000);
    });
    //user supplies 1000 wCanto to cCanto LM in order to then borrow Note
    it("User Supplies 1000 wCanto to cCanto Lending Market", async () => {
        //support Market in Comptroller before running test 
        const txAdd = await Comptroller._supportMarket(CCanto.address);
        await txAdd.wait();
        expect((await Comptroller.getAllMarkets())
            .find(m => m == CCanto.address)).to.equal(CCanto.address);
        // deployer enters into cCanto LM 
        let tx = await Comptroller.enterMarkets([CCanto.address]);
        const resp = await tx.wait();
        //check for enterMarkets event
        const ev = resp.events.find(e => e.event === 'MarketEntered');
        if (!(await Comptroller.checkMembership(deployer.address, CCanto.address))){
            console.log(ev.args);
        }
        //check that deployer is entered in the cCanto Lending Market 
        expect(await Comptroller.checkMembership(deployer.address, CCanto.address))
            .to.be.true;
        expect((await Comptroller.getAssetsIn(deployer.address))
            .find(m => m == CCanto.address)).to.equal(CCanto.address);
        //approve transfer into CNote lending market
        await WCanto["approve(address,address)"](deployer.address, CCanto.address); //overloaded function
        await (await CCanto.mint(1000)).wait(); // supply 1000 wCanto to cCanto Lending Market
    
        const exRate = await CCanto.exchangeRateStored();
        const cTokenBalance = (ethers.BigNumber.from(1000)).div(ethers.BigNumber.from(exRate));
        expect(
            ethers.BigNumber.from(await CCanto.callStatic.
                balanceOfUnderlying(deployer.address)).mul(ethers.BigNumber.from(10).pow(18)))
            .to.equal(await CCanto.balanceOf(deployer.address));
        
    });
    
    //borrow deployer.address.AccoutLiquidity of Note from CNote LendingMarket, identify amt of interest Treasury earns
    it("Note Borrow before/after calculations", async () => {
        //deployer enters into the CNote LM
        const txEnter = await Comptroller.enterMarkets([cnote]);
        await txEnter.wait();
        expect(await Comptroller.checkMembership(deployer.address, cnote)).to.be.true;
        // //deployer borrows deployer.address.AcctLiquidity Note, calculate price based upon simple price oralce
        await (await PriceOracle.setUnderlyingPrice(cnote, 1)).wait();
        acctSnap = await Comptroller.getAccountLiquidity(deployer.address);
        const txBorrow = await (await CNote.borrow(acctSnap[1])).wait();
        // const ev = txBorrow.events.find(e => e.event === 'AcctSupplied');
        // console.log(ev.args);
        // //ensure that borrower does not enter shortfall territory
        expect(await Note.balanceOf(accountant)).to.equal(await Note.totalSupply())
        expect((await Comptroller.getAccountLiquidity(deployer.address))[1]).to.equal(0);
        expect(await CNote.totalSupply()).to.equal(0);
        //
    });

});