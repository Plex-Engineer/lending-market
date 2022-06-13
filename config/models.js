const { ethers } = require("hardhat");

const NoteModel = {
    baseRatePerYear: "2000000000000000",
    adjusterCoefficient: 1,
};  

const JumpModel = {
    baseRatePerYear:"2500000000000000",
    multiplierPerYear:"20000000000000000",
    jumpMultiplierPerYear:"1090000000000000000",
    kink_: "50000000000000000"
};

module.exports = {
   "canto" : [{NoteModel}, {JumpModel}],
};