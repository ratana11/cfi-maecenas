var Crowdsale = artifacts.require("./MaecenasCrowdsale.sol");   //For testing use this .sol
var Token = artifacts.require("./MaecenasToken.sol");           // For testing use this .sol
var SafeMathLib = artifacts.require("./Utils/SafeMath.sol");

module.exports = function(deployer) {

  var crowdsaleContract;
  var tokenContract;
  return Token.deployed().then(function(_tokenInstance) {
    tokenContract = _tokenInstance;
  return Crowdsale.deployed().then(function(_crowdsaleInstance) {
    crowdsaleContract = _crowdsaleInstance;
  return crowdsaleContract.setToken(tokenContract.address);
  });
  });
};
