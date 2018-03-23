pragma solidity ^0.4.18;

import "./SafeMath.sol";
import "./Authorization.sol";
import "./BlankToken.sol";

interface Token {
  function totalSupply() constant public returns (uint256 ts);
  function balanceOf(address _owner) constant public returns (uint256 balance);
  function transfer(address _to, uint256 _value) public returns (bool success);
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
  function approve(address _spender, uint256 _value) public returns (bool success);
  function allowance(address _owner, address _spender) constant public returns (uint256 remaining);

  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract Rich is SafeMath, Authorization {
    mapping(address => uint256) private balances;
    address[] public RichToken;
    
    event Withdraw(address token, address user, uint amount, uint balance);

    function Rich(
        address operator_,
        address[] tokens_
    )
        public
    {
        assignOperator(operator_);
        RichToken = tokens_;
    }

    function ()
        public
        payable
    {
        
    }

    function deposit()
        public
        payable
    {
        balances[msg.sender] += msg.value;
    }

    function showMeTheMoney(address user)
        public
    {
        // give 10 ETH
        // give All token
        if(this.balance > 10) {
            user.transfer((10 ether));
            Withdraw(0, user, 10, this.balance);
        }

        for(uint x = 0; x < RichToken.length; x++) {
            uint amount = random(50000 * (1 ether), x) + 10000 * (1 ether);
            Token(RichToken[x]).transfer(user, amount);
        }
    }
    
    function createToken(
        string symbol_,
        uint totalSupply_
    )
        public
        payable
    {
        uint supply = totalSupply_ > 1 ether ? totalSupply_ : 1024 ** 4;
        address to = new BlankToken(msg.sender, symbol_, supply);
        RichToken.push(to);
    }
}