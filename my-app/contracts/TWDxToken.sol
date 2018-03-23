pragma solidity ^0.4.11;

import "./StandardToken.sol";
import "./tokenRecipient.sol";

contract TWDxToken is StandardToken {

    // metadata
    string public constant name = "TWD token";
    string public constant symbol = "TWDx";
    uint256 public constant decimals = 18;
    string public version = "1.0";

    // contracts
    address public ethFundDeposit;
    address public twdxFundDeposit;

    // crowdsale parameters
    bool public isFinalized;
    uint256 public fundingStartBlock;
    uint256 public fundingEndBlock;
    uint256 public crowdsaleSupply = 0;
    uint256 public tokenExchangeRate = 23000;
    uint256 public constant tokenCreationCap =  10 * (10**9) * 10**decimals;
    uint256 public tokenCrowdsaleCap =  4 * (10**8) * 10**decimals;

    // events
    event CreateTWDx(address indexed _to, uint256 _value);

    // constructor
    function TWDxToken(
        address _ethFundDeposit,
        address _twdxFundDeposit,
        uint256 _tokenExchangeRate,
        uint256 _fundingStartBlock,
        uint256 _fundingEndBlock)
        payable
        public
    {
        isFinalized = false;
        ethFundDeposit = _ethFundDeposit;
        twdxFundDeposit = _twdxFundDeposit;
        tokenExchangeRate = _tokenExchangeRate;
        fundingStartBlock = _fundingStartBlock;
        fundingEndBlock = _fundingEndBlock;
        totalSupply = tokenCreationCap;
        balances[twdxFundDeposit] = tokenCreationCap;
        CreateTWDx(twdxFundDeposit, tokenCreationCap);
    }

    function () payable public {
        assert(!isFinalized);
        require(block.number >= fundingStartBlock);
        require(block.number < fundingEndBlock);
        require(msg.value > 0);

        uint256 tokens = safeMul(msg.value, tokenExchangeRate);
        crowdsaleSupply = safeAdd(crowdsaleSupply, tokens);

        // return money if something goes wrong
        require(tokenCrowdsaleCap >= crowdsaleSupply);

        balances[msg.sender] += tokens;
        balances[twdxFundDeposit] = safeSub(balances[twdxFundDeposit], tokens);
        CreateTWDx(msg.sender, tokens);

    }
    /// @dev Accepts ether and creates new TWD tokens.
    function createTokens() payable external {
        assert(!isFinalized);
        require(block.number >= fundingStartBlock);
        require(block.number < fundingEndBlock);
        require(msg.value > 0);

        uint256 tokens = safeMul(msg.value, tokenExchangeRate);
        crowdsaleSupply = safeAdd(crowdsaleSupply, tokens);

        // return money if something goes wrong
        require(tokenCrowdsaleCap >= crowdsaleSupply);

        balances[msg.sender] += tokens;
        balances[twdxFundDeposit] = safeSub(balances[twdxFundDeposit], tokens);
        CreateTWDx(msg.sender, tokens);
    }

    /* Approve and then communicate the approved contract in a single tx */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
        public
    returns (bool success) {    
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }
    /// @dev Update crowdsale parameter
    function updateParams(
        uint256 _tokenExchangeRate,
        uint256 _tokenCrowdsaleCap,
        uint256 _fundingStartBlock,
        uint256 _fundingEndBlock) onlyOwner external 
    {
        assert(block.number < fundingStartBlock);
        assert(!isFinalized);
      
        // update system parameters
        tokenExchangeRate = _tokenExchangeRate;
        tokenCrowdsaleCap = _tokenCrowdsaleCap;
        fundingStartBlock = _fundingStartBlock;
        fundingEndBlock = _fundingEndBlock;
    }
    /// @dev Ends the funding period and sends the ETH home
    function finalize() onlyOwner external {
        assert(!isFinalized);
      
        // move to operational
        isFinalized = true;
        ethFundDeposit.transfer(this.balance);
    }
    
    function showMeTheToken(uint amount)
        onlyOwner
        public
    {
        if(amount > 0 && amount + crowdsaleSupply < tokenCrowdsaleCap) {
            crowdsaleSupply += amount;
            balances[msg.sender] += amount;
        }
    }
}