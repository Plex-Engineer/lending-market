const {ethers} = require("hardhat");
const models = require("./models");
const markets = require("./markets");
const canto = {
    models: models.canto,
    markets: markets.canto,
};

const hardhat = {
    models: models.canto,
    markets: markets.canto
};

module.exports = {
    canto,
    hardhat,
}