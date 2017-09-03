var Crowdsale = artifacts.require("./MaecenasCrowdsale.sol");   //For testing use this .sol
var Token = artifacts.require("./MaecenasToken.sol");           // For testing use this .sol
var SafeMathLib = artifacts.require("./Utils/SafeMath.sol");

module.exports = function(deployer) {
  deployer.deploy(SafeMathLib);
  deployer.link(SafeMathLib, Token);
  deployer.deploy(Token, Crowdsale.deployed().then(function(crowdsaleInsance){return crowdsaleInsance.address}), 4366494);
};
