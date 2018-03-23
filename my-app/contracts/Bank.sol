pragma solidity ^0.4.18;

import "./SafeMath.sol";
import "./Authorization.sol";

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

contract Bank is SafeMath, Authorization {
    struct Account {
        mapping(address => uint256) balance;
        mapping(address => uint256) freeze;
    }
    mapping(address => Account) private accounts;

    event Deposit(address user, address token, uint256 amount, address operator);
    event Withdraw(address user, address token, uint256 amount, address operator);
    event Transfer(address user, address token, uint256 amount, address receiver, address operator);

    function Bank(address operator_)
        public
    {
        authbook[operator_] = true;
    }

    function balanceOf(address user_, address token_)
        public
        view
    returns(uint256) {
        return accounts[user_].balance[token_];
    }
    function freezeOf(address user_, address token_)
        public
        view
    returns(uint256) {
        return accounts[user_].freeze[token_];
    }

    function deposit()
        public
        payable
        onlyActive
    {
        accounts[msg.sender].balance[0] = safeAdd(accounts[msg.sender].balance[0], msg.value);
        Deposit(msg.sender, 0, msg.value, msg.sender);
    }
    function depositToken(address token_, uint256 amount_)
        public
        payable
        onlyActive
    {
        if(token_ == 0x0000000000000000000000000000000000000000) {
            require(msg.value == amount_);
        } else {
            require(Token(token_).transferFrom(msg.sender, this, amount_));
        }
        accounts[msg.sender].balance[token_] = safeAdd(accounts[msg.sender].balance[token_], amount_);
        Deposit(msg.sender, token_, amount_, msg.sender);
    }
    function depositToAccount(address user_, address token_, uint256 amount_)
        public
        payable
        onlyActive
    {
        if(token_ == 0x0000000000000000000000000000000000000000) {
            require(amount_ == msg.value);
        } else {
            require(Token(token_).transferFrom(msg.sender, this, amount_));
        }
        accounts[user_].balance[token_] = safeAdd(accounts[user_].balance[token_], amount_);
        Deposit(user_, token_, amount_, msg.sender);
    }
    function depositToFreeze(address user_, address token_, uint256 amount_)
        public
        payable
        onlyOperator
        onlyActive
    returns(bool) {
        if(token_ == 0x0000000000000000000000000000000000000000) {
            require(amount_ == msg.value);
        } else {
            require(Token(token_).transferFrom(msg.sender, this, amount_));
        }
        accounts[user_].freeze[token_] = safeAdd(accounts[user_].freeze[token_], amount_);
        Deposit(user_, token_, amount_, msg.sender);
        return true;
    }
    
    function withdraw(uint256 amount_)
        public
        onlyActive
    {
        require(
            accounts[msg.sender].balance[0] >= amount_ &&
            this.balance >= amount_
        );
        accounts[msg.sender].balance[0] = safeSub(accounts[msg.sender].balance[0], amount_);
        msg.sender.transfer(amount_);
        Withdraw(msg.sender, 0, amount_, msg.sender);
    }
    function withdrawToken(address token_, uint256 amount_)
        public
        onlyActive
    {
        if(token_ == 0x0000000000000000000000000000000000000000) {
            withdraw(amount_);
        } else {
            require(
                accounts[msg.sender].balance[token_] >= amount_ &&
                Token(token_).balanceOf(this) >= amount_
            );
            accounts[msg.sender].balance[token_] = safeSub(accounts[msg.sender].balance[token_], amount_);
            Token(token_).transfer(msg.sender, amount_);
            Withdraw(msg.sender, token_, amount_, msg.sender);
        }
    }
    function withdrawFromFreeze(address user_, address token_, uint256 amount_)
        public
        onlyOperator
        onlyActive
    returns(bool) {
        require(
            accounts[user_].freeze[token_] >= amount_
        );
        if(token_ == 0x0000000000000000000000000000000000000000) {
            require(this.balance >= amount_);
            user_.transfer(amount_);
        } else {
            require(Token(token_).balanceOf(this) >= amount_);
            require(Token(token_).transfer(user_, amount_));
        }
        accounts[user_].freeze[token_] = safeSub(accounts[user_].freeze[token_], amount_);
        Withdraw(user_, token_, amount_, msg.sender);
        return true;
    }
    
    function transfer(address receiver_, address token_, uint256 amount_)
        public
        onlyActive
    returns(bool) {
        require(
            accounts[msg.sender].balance[token_] >= amount_ &&
            amount_ > 0
        );
        accounts[msg.sender].balance[token_] = safeSub(accounts[msg.sender].balance[token_], amount_);
        accounts[receiver_].balance[token_] = safeAdd(accounts[receiver_].balance[token_], amount_);
        return true;
    }
    function transferFromFreeze(address user_, address token_, uint256 amount_, address receiver_)
        public
        onlyOperator
        onlyActive
    returns(bool) {
        require(
            accounts[user_].freeze[token_] >= amount_ &&
            amount_ > 0
        );
        if(token_ == 0x0000000000000000000000000000000000000000) {
            require(
                this.balance >= amount_
            );
            receiver_.transfer(amount_);
        } else {
            require(
                Token(token_).balanceOf(this) >= amount_
            );
            Token(token_).transfer(receiver_, amount_);
        }
        accounts[user_].freeze[token_] = safeSub(accounts[user_].freeze[token_], amount_);
        Transfer(user_, token_, amount_, receiver_, msg.sender);
        return true;
    }
}