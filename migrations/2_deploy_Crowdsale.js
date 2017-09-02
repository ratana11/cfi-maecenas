var Crowdsale = artifacts.require("./MaecenasCrowdsale.sol"); // For testing use this .sol

module.exports = function(deployer) {
  deployer.deploy(Crowdsale);
};
