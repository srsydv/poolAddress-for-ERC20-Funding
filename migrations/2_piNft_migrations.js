const PiNFT = artifacts.require("piNFT");
const SampleERC20 = artifacts.require("mintToken");

module.exports = function (deployer) {
  deployer.deploy(PiNFT, "Aconomy", "ACO");
  deployer.deploy(SampleERC20, "1000000");
};