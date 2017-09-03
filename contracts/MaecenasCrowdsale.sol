pragma solidity ^0.4.13;

import "./Crowdsale.sol";

contract MaecenasCrowdsale is Crowdsale {
  function MaecenasCrowdsale(){
    presaleStartBlock = 4241483;
    presaleUnlimitedStartBlock = 4245055;
    crowdsaleStartBlock = 4248627;
    crowdsaleEndedBlock = 4348635;

    minCap = 9375 * 10**18;
    maxP1Cap = 31250 * 10**18;
    maxCap = 62500 * 10**18;

    ethToTokenConversion = 480;

    maxTokenSupply = 100000000 * 10**18;
    cofounditReward = 4000000 * 10**18;
    cofounditAddress = 0x988c3eA5554f3D2fB5ECB4dC5c35126eEf3B8a5D;
  }
}
