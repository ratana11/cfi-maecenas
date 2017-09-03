pragma solidity ^0.4.13;

import "./Crowdsale.sol";

contract MaecenasCrowdsale is Crowdsale {
  function MaecenasCrowdsale(){
    presaleStartBlock = 0; //TODO: Set proper block number
    presaleUnlimitedStartBlock = 0; //TODO: Set proper block number
    crowdsaleStartBlock = 0; //TODO: Set proper block number
    crowdsaleEndedBlock = 0; //TODO: Set proper block number

    minCap = 9375 * 10**18;
    maxP1Cap = 31250 * 10**18;
    maxCap = 62500 * 10**18;

    ethToTokenConversion = 480;

    maxTokenSupply = 100000000 * 10**18;
    cofounditReward = 4000000 * 10**18;
    cofounditAddress = 0x0;
  }
}
