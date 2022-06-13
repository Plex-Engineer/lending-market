import { HardhatRuntimeEnvironment  } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/dist/types";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
    const {ethers, deployments, getNamedAccounts } = hre;
    const { deploy, execute, read } = deployments;

    const { deployer } = await getNamedAccounts();
    //deploy Accountant
    const Accountant = await deploy("AccountantDelegate", {
        from: deployer,
        log: true
    });

    //retrieve Comptroller Object
    const Comptroller = new ethers.Contract(
        (await deployments.get("Unitroller")).address,
        (await deployments.get("Comptroller")).abi,
        ethers.provider.getSigner(deployer)
    );
    //retrieve cNote Object
    const cNote = await deployments.get("CErc20Delegator"); //cNote Delegator address
    
    await (await Comptroller._supportMarket(cNote.address)).wait();

    // deploy Note, and set the accountant address
    const Note = await deployments.get("Note");
                
    // deploy TreasuryDelegator
    const Treasury = await deployments.get("TreasuryDelegator");
        
    const args = [
        Accountant.address,
        deployer,
        cNote.address,
        Note.address,
        Comptroller.address,
        Treasury.address
    ];
    //Accountant Delegator initialized, and linked to Accountant via AwccountantDelegator.delegatecall(Accountant.initialize()); 
    const AccountantDelegator = await deploy("AccountantDelegator", {
        from: deployer,
        log: true,
        args: args,
    });
    };

export default func;
func.tags = ["Accountant", "Protocol"];
func.dependencies= ["NoteConfig", "Markets","ComptrollerConfig", "TreasuryConfig"];