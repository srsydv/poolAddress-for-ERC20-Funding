const PiMarket = artifacts.require("piMarket");
// require("dotenv").config();

module.exports = function (deployer) {
  deployer.deploy(PiMarket, "0x7852ef7e88f74138755883fee684abc50af3341e");
};