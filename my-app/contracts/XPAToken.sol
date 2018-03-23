pragma solidity ^0.4.11;

import "./StandardToken.sol";
import "./tokenRecipient.sol";

contract XPAToken is StandardToken {

    // metadata
    string public constant name = "XPlay Token";
    string public constant symbol = "XPA";
    uint256 public constant decimals = 18;
    string public version = "1.0";

    // contracts
    address public ethFundDeposit;      // deposit address of ETH for XPlay Ltd.
    address public xpaFundDeposit;      // deposit address for XPlay Ltd. use and XPA User Fund

    // crowdsale parameters
    bool public isFinalized;              // switched to true in operational state
    uint256 public fundingStartBlock;
    uint256 public fundingEndBlock;
    uint256 public crowdsaleSupply = 0;         // crowdsale supply
    uint256 public tokenExchangeRate = 23000;   // 23000 XPA tokens per 1 ETH
    uint256 public constant tokenCreationCap =  10 * (10**9) * 10**decimals;
    uint256 public tokenCrowdsaleCap =  4 * (10**8) * 10**decimals;

    // events
    event CreateXPA(address indexed _to, uint256 _value);

    // constructor
    function XPAToken(
        address _ethFundDeposit,
        address _xpaFundDeposit,
        uint256 _tokenExchangeRate,
        uint256 _fundingStartBlock,
        uint256 _fundingEndBlock)
        payable
        public
    {
        isFinalized = false;                   //controls pre through crowdsale state
        ethFundDeposit = _ethFundDeposit;
        xpaFundDeposit = _xpaFundDeposit;
        tokenExchangeRate = _tokenExchangeRate;
        fundingStartBlock = _fundingStartBlock;
        fundingEndBlock = _fundingEndBlock;
        totalSupply = tokenCreationCap;
        balances[xpaFundDeposit] = tokenCreationCap;    // deposit all XPA to XPlay Ltd.
        CreateXPA(xpaFundDeposit, tokenCreationCap);    // logs deposit of XPlay Ltd. fund
    }

    function () payable public {
        assert(!isFinalized);
        require(block.number >= fundingStartBlock);
        require(block.number < fundingEndBlock);
        require(msg.value > 0);

        uint256 tokens = safeMul(msg.value, tokenExchangeRate);    // check that we're not over totals
        crowdsaleSupply = safeAdd(crowdsaleSupply, tokens);

        // return money if something goes wrong
        require(tokenCrowdsaleCap >= crowdsaleSupply);

        balances[msg.sender] += tokens;     // add amount of XPA to sender
        balances[xpaFundDeposit] = safeSub(balances[xpaFundDeposit], tokens); // subtracts amount from XPlay's balance
        CreateXPA(msg.sender, tokens);      // logs token creation

    }
    /// @dev Accepts ether and creates new XPA tokens.
    function createTokens() payable external {
        assert(!isFinalized);
        require(block.number >= fundingStartBlock);
        require(block.number < fundingEndBlock);
        require(msg.value > 0);

        uint256 tokens = safeMul(msg.value, tokenExchangeRate);    // check that we're not over totals
        crowdsaleSupply = safeAdd(crowdsaleSupply, tokens);

        // return money if something goes wrong
        require(tokenCrowdsaleCap >= crowdsaleSupply);

        balances[msg.sender] += tokens;     // add amount of XPA to sender
        balances[xpaFundDeposit] = safeSub(balances[xpaFundDeposit], tokens); // subtracts amount from XPlay's balance
        CreateXPA(msg.sender, tokens);      // logs token creation
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
        ethFundDeposit.transfer(this.balance);              // send the eth to XPlay ltd.
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