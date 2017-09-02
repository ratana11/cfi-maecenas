pragma solidity ^0.4.13;

import "./Utils/ReentrnacyHandlingContract.sol";
import "./Utils/Owned.sol";
import "./Interfaces/IToken.sol";
import "./Interfaces/IERC20Token.sol";

contract Crowdsale is ReentrnacyHandlingContract, Owned{

  struct ContributorData{
    uint priorityPassAllowance;
    bool isActive;
    uint contributionAmount;
    uint tokensIssued;
  }

  mapping(address => ContributorData) public contributorList;
  uint nextContributorIndex;
  mapping(uint => address) contributorIndexes;

  state public crowdsaleState = state.pendingStart;
  enum state { pendingStart, priorityPass, openedPriorityPass, crowdsale, crowdsaleEnded }

  uint public presaleStartBlock;
  uint public presaleUnlimitedStartBlock;
  uint public crowdsaleStartBlock;
  uint public crowdsaleEndedBlock;

  event PresaleStarted(uint blockNumber);
  event PresaleUnlimitedStarted(uint blockNumber);
  event CrowdsaleStarted(uint blockNumber);
  event CrowdsaleEnded(uint blockNumber);
  event ErrorSendingETH(address to, uint amount);
  event MinCapReached(uint blockNumber);
  event MaxCapReached(uint blockNumber);

  IToken token = IToken(0x0);
  uint ethToTokenConversion;

  uint public minCap;
  uint public maxP1Cap;
  uint public maxCap;
  uint public ethRaised;

  address public multisigAddress;

  uint nextContributorToClaim;
  mapping(address => bool) hasClaimedEthWhenFail;

  uint maxTokenSupply;
  bool ownerHasClaimedTokens;
  uint cofounditReward;
  address cofounditAddress;
  bool cofounditHasClaimedTokens;

  //
  // Unnamed function that runs when eth is sent to the contract
  //
  function() noReentrancy payable{
    require(msg.value != 0);                        // Throw if value is 0
    require(crowdsaleState != state.crowdsaleEnded);// Check if crowdsale has ended

    bool stateChanged = checkCrowdsaleState();      // Check blocks and calibrate crowdsale state

    if (crowdsaleState == state.priorityPass){
      if (contributorList[msg.sender].isActive){    // Check if contributor is in priorityPass
        processTransaction(msg.sender, msg.value);  // Process transaction and issue tokens
      }else{
        refundTransaction(stateChanged);            // Set state and return funds or throw
      }
    }
    else if(crowdsaleState == state.openedPriorityPass){
      if (contributorList[msg.sender].isActive){    // Check if contributor is in priorityPass
        processTransaction(msg.sender, msg.value);  // Process transaction and issue tokens
      }else{
        refundTransaction(stateChanged);            // Set state and return funds or throw
      }
    }
    else if(crowdsaleState == state.crowdsale){
      processTransaction(msg.sender, msg.value);    // Process transaction and issue tokens
    }
    else{
      refundTransaction(stateChanged);              // Set state and return funds or throw
    }
  }

  //
  // Check crowdsale state and calibrate it
  //
  function checkCrowdsaleState() internal returns (bool){
    if (ethRaised == maxCap && crowdsaleState != state.crowdsaleEnded){                         // Check if max cap is reached
      crowdsaleState = state.crowdsaleEnded;
      MaxCapReached(block.number);                                                              // Close the crowdsale
      CrowdsaleEnded(block.number);                                                             // Raise event
      return true;
    }

    if (block.number > presaleStartBlock && block.number <= presaleUnlimitedStartBlock){  // Check if we are in presale phase
      if (crowdsaleState != state.priorityPass){                                          // Check if state needs to be changed
        crowdsaleState = state.priorityPass;                                              // Set new state
        PresaleStarted(block.number);                                                     // Raise event
        return true;
      }
    }else if(block.number > presaleUnlimitedStartBlock && block.number <= crowdsaleStartBlock){ // Check if we are in presale unlimited phase
      if (crowdsaleState != state.openedPriorityPass){                                          // Check if state needs to be changed
        crowdsaleState = state.openedPriorityPass;                                              // Set new state
        PresaleUnlimitedStarted(block.number);                                                  // Raise event
        return true;
      }
    }else if(block.number > crowdsaleStartBlock && block.number <= crowdsaleEndedBlock){        // Check if we are in crowdsale state
      if (crowdsaleState != state.crowdsale){                                                   // Check if state needs to be changed
        crowdsaleState = state.crowdsale;                                                       // Set new state
        CrowdsaleStarted(block.number);                                                         // Raise event
        return true;
      }
    }else{
      if (crowdsaleState != state.crowdsaleEnded && block.number > crowdsaleEndedBlock){        // Check if crowdsale is over
        crowdsaleState = state.crowdsaleEnded;                                                  // Set new state
        CrowdsaleEnded(block.number);                                                           // Raise event
        return true;
      }
    }
    return false;
  }

  //
  // Decide if throw or only return ether
  //
  function refundTransaction(bool _stateChanged) internal{
    if (_stateChanged){
      msg.sender.transfer(msg.value);
    }else{
      revert();
    }
  }

  //
  // Calculate how much user can contribute
  //
  function calculateMaxContribution(address _contributor) constant returns (uint maxContribution){
    uint maxContrib;
    if (crowdsaleState == state.priorityPass){    // Check if we are in priority pass
      maxContrib = contributorList[_contributor].priorityPassAllowance - contributorList[_contributor].contributionAmount;
      if (maxContrib > (maxP1Cap - ethRaised)){   // Check if max contribution is more that max cap
        maxContrib = maxP1Cap - ethRaised;        // Alter max cap
      }
    }
    else{
      maxContrib = maxCap - ethRaised;            // Alter max cap
    }
    return maxContrib;
  }

  //
  // Issue tokens and return if there is overflow
  //
  function processTransaction(address _contributor, uint _amount) internal{
    uint maxContribution = calculateMaxContribution(_contributor);              // Calculate max users contribution
    uint contributionAmount = _amount;
    uint returnAmount = 0;
    if (maxContribution < _amount){                                             // Check if max contribution is lower than _amount sent
      contributionAmount = maxContribution;                                     // Set that user contibutes his maximum alowed contribution
      returnAmount = _amount - maxContribution;                                 // Calculate howmuch he must get back
    }

    if (ethRaised + contributionAmount > minCap && minCap < ethRaised) MinCapReached(block.number);

    if (contributorList[_contributor].isActive == false){                       // Check if contributor has already contributed
      contributorList[_contributor].isActive = true;                            // Set his activity to true
      contributorList[_contributor].contributionAmount = contributionAmount;    // Set his contribution
      contributorIndexes[nextContributorIndex] = _contributor;                  // Set contributors index
      nextContributorIndex++;
    }
    else{
      contributorList[_contributor].contributionAmount += contributionAmount;   // Add contribution amount to existing contributor
    }
    ethRaised += contributionAmount;                                            // Add to eth raised

    uint tokenAmount = contributionAmount * ethToTokenConversion;               // Calculate how much tokens must contributor get
    if (tokenAmount > 0){
      token.mintTokens(_contributor, tokenAmount);                                // Issue new tokens
      contributorList[_contributor].tokensIssued += tokenAmount;                  // log token issuance
    }
    if (returnAmount != 0) _contributor.transfer(returnAmount);                 // Return overflow of ether
  }

  //
  // Push contributor data to the contract before the crowdsale so that they are eligible for priorit pass
  //
  function editContributors(address[] _contributorAddresses, uint[] _contributorPPAllowances) onlyOwner{
    require(_contributorAddresses.length == _contributorPPAllowances.length); // Check if input data is correct

    for(uint cnt = 0; cnt < _contributorAddresses.length; cnt++){
      if (contributorList[_contributorAddresses[cnt]].isActive){
        contributorList[_contributorAddresses[cnt]].priorityPassAllowance += _contributorPPAllowances[cnt];
      }
      else{
        contributorList[_contributorAddresses[cnt]].isActive = true;
        contributorList[_contributorAddresses[cnt]].priorityPassAllowance = _contributorPPAllowances[cnt];
        contributorIndexes[nextContributorIndex] = _contributorAddresses[cnt];
        nextContributorIndex++;
      }
    }
  }

  //
  // Method is needed for recovering tokens accedentaly sent to token address
  //
  function salvageTokensFromContract(address _tokenAddress, address _to, uint _amount) onlyOwner{
    IERC20Token(_tokenAddress).transfer(_to, _amount);
  }

  //
  // withdrawEth when minimum cap is reached
  //
  function withdrawEth() onlyOwner{
    require(this.balance != 0);
    require(ethRaised >= minCap);

    pendingEthWithdrawal = this.balance;
  }
  uint pendingEthWithdrawal;
  function sanityCheck(){
    require(msg.sender == multisigAddress);
    require(pendingEthWithdrawal > 0);

    multisigAddress.transfer(pendingEthWithdrawal);
    pendingEthWithdrawal = 0;
  }

  //
  // Users can claim their contribution if min cap is not raised
  //
  function claimEthIfFailed(){
    require(block.number > crowdsaleEndedBlock && ethRaised < minCap);    // Check if crowdsale has failed
    require(contributorList[msg.sender].contributionAmount > 0);          // Check if contributor has contributed to crowdsaleEndedBlock
    require(!hasClaimedEthWhenFail[msg.sender]);                          // Check if contributor has already claimed his eth

    uint ethContributed = contributorList[msg.sender].contributionAmount; // Get contributors contribution
    hasClaimedEthWhenFail[msg.sender] = true;                             // Set that he has claimed
    if (!msg.sender.send(ethContributed)){                                // Refund eth
      ErrorSendingETH(msg.sender, ethContributed);                        // If there is an issue raise event for manual recovery
    }
  }

  //
  // Owner can batch return contributors contributions(eth)
  //
  function batchReturnEthIfFailed(uint _numberOfReturns) onlyOwner{
    require(block.number > crowdsaleEndedBlock && ethRaised < minCap);                // Check if crowdsale has failed
    address currentParticipantAddress;
    uint contribution;
    for (uint cnt = 0; cnt < _numberOfReturns; cnt++){
      currentParticipantAddress = contributorIndexes[nextContributorToClaim];         // Get next unclaimed participant
      if (currentParticipantAddress == 0x0) return;                                   // Check if all the participants were compensated
      if (!hasClaimedEthWhenFail[currentParticipantAddress]) {                        // Check if participant has already claimed
        contribution = contributorList[currentParticipantAddress].contributionAmount; // Get contribution of participant
        hasClaimedEthWhenFail[currentParticipantAddress] = true;                      // Set that he has claimed
        if (!currentParticipantAddress.send(contribution)){                           // Refund eth
          ErrorSendingETH(currentParticipantAddress, contribution);                   // If there is an issue raise event for manual recovery
        }
      }
      nextContributorToClaim += 1;                                                    // Repeat
    }
  }

  //
  // If there were any issue/attach with refund owner can withraw eth at the end for manual recovery
  //
  function withdrawRemainingBalanceForManualRecovery() onlyOwner{
    require(this.balance != 0);                                  // Check if there are any eth to claim
    require(block.number > crowdsaleEndedBlock);                 // Check if crowdsale is over
    require(contributorIndexes[nextContributorToClaim] == 0x0);  // Check if all the users were refunded
    multisigAddress.transfer(this.balance);                      // Withdraw to multisig
  }

  //
  // Owner can set multisig address for crowdsale
  //
  function setMultisigAddress(address _newAddress) onlyOwner{
    multisigAddress = _newAddress;
  }

  //
  // Owner can set token address where mints will happen
  //
  function setToken(address _newAddress) onlyOwner{
    token = IToken(_newAddress);
  }

  //
  // Owner can claim teams tokens when crowdsale has successfully ended
  //
  function claimCoreTeamsTokens(address _to) onlyOwner{
    require(crowdsaleState == state.crowdsaleEnded);              // Check if crowdsale has ended
    require(!ownerHasClaimedTokens);                              // Check if owner has allready claimed tokens

    uint devReward = maxTokenSupply - token.totalSupply();
    if (!cofounditHasClaimedTokens) devReward -= cofounditReward; // If cofoundit has claimed tokens its ok if not set aside cofounditReward
    token.mintTokens(_to, devReward);                             // Issue Teams tokens
    ownerHasClaimedTokens = true;                                 // Block further mints from this method
  }

  //
  // Cofoundit can claim their tokens
  //
  function claimCofounditTokens(address _to){
    require(msg.sender == cofounditAddress);            // Check if sender is cofoundit
    require(crowdsaleState == state.crowdsaleEnded);    // Check if crowdsale has ended
    require(!cofounditHasClaimedTokens);                // Check if cofoundit has allready claimed tokens

    token.mintTokens(_to, cofounditReward);             // Issue cofoundit tokens
    cofounditHasClaimedTokens = true;                   // Block further mints from this method
  }

  function getTokenAddress() constant returns(address){
    return address(token);
  }
}
