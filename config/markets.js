const {ethers} = require("hardhat");

const CNote = {
    initialExchangeRateMantissa: "1000000000000000000",
    name: "CNote",
    symbol: "CNOTE",
    decimals: "18",
    becomeImplementation: [],
};

const CEther = {
    initialExchangeRateMantissa: "1000000000000000000",
    name: "CCanto",
    symbol: "cCANTO",
    decimals: "18",    
};  

module.exports= {
    "canto" : {CNote, CEther}, 
}