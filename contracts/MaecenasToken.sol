pragma solidity ^0.4.13;

import "./Token.sol";

contract MaecenasToken is Token {

  /* Initializes contract */
  function MaecenasToken(address _crowdsaleAddress, uint _tokenStartBlock) {
    standard = "Maecenas token v1.0";
    name = "Maecenas ART Token";
    symbol = "ART";
    decimals = 18;
    crowdsaleContractAddress = _crowdsaleAddress;
    lockFromSelf(_tokenStartBlock, "Lock before crowdsale starts");
  }
}
