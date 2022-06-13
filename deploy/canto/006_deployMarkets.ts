import { HardhatRuntimeEnvironment  } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/dist/types";
import {canto} from "../../config/index.js";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
    const {ethers, deployments, getNamedAccounts } = hre;
    const { deploy, execute, read } = deployments;
    const { deployer } = await getNamedAccounts();

    const markets = canto.markets;

    //retrieve deployments and link it to the cNote Lending Market
    const Note = await deployments.get("Note");
    //instance of unitroller with comptroller abi
    const Comptroller = new hre.ethers.Contract(
         (await deployments.get("Unitroller")).address,
         (await deployments.get("Comptroller")).abi,
         hre.ethers.provider.getSigner(deployer)
    );  

    //Note Interest Rate Model
    const NoteModel = await deployments.get("JumpRateModel");    
    //deploy current implementation of cNote Market
    const cNote = await deploy("CNote", {
        from: deployer,
        log: true
    });

    //retrieve markets configuration for canto CLM, set admin to deployer for now (should be Timelock)
    const CNoteArgs = [
        Note.address, //underlying
        Comptroller.address, //ComptrollerInterface
        NoteModel.address, //interestRateModel
        markets.CNote.initialExchangeRateMantissa, //initialExchangeRateMantissa
        markets.CNote.name,
        markets.CNote.symbol,
        markets.CNote.decimals,
        deployer, //admin
        cNote.address, //implementation
        markets.CNote.becomeImplementation, //data for _becomeImplementationdata
    ];

    //deploy CErc20Delegator and ensure that they are linked
    const CNoteDelegator = await deploy("CErc20Delegator", {
        from: deployer,
        log: true,
        args: CNoteArgs
    });

    //sanity check that the markets have been linked
    if(await read("CErc20Delegator", "implementation") != cNote.address){
        //most likely, this conditional will not have been met, however to ensure integrity set the impl
        await execute("CErc20Delegator", 
            {from: deployer, log: true},
            "_setImplementation", 
            (await deployments.get("CNote")).address,
            false, //do not allow resignation
            [] //become implementation is currently unused
        );
    }
    //deploy CEther, A market for Canto
    const CantoArgs = [
        Comptroller.address,
        NoteModel.address,
        markets.CEther.initialExchangeRateMantissa,
        markets.CEther.name,
        markets.CEther.symbol,
        markets.CEther.decimals,
        deployer,
    ];

    const CCanto = await deploy("CEther", {
        from: deployer,
        log: true,
        args: CantoArgs
    });

};

export default func;
func.tags = ["Markets", "Protocol"];
func.dependencies = ["NoteConfig", "ComptrollerConfig", "Models"];
