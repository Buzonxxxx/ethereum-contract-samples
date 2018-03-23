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
}

/*  Error Code
    0: insufficient funds (user)
    1: insufficient funds (contract)
    2: amount too large
    3: amount too low
*/

contract Baliv is SafeMath, Authorization {
    struct Order {
        address user;
        address fromToken;
        uint256 fromAmount;
        address toToken;
        uint256 price;
        uint256 filled;
        uint8 status;     // 0: cancel, 1: active, 2: fullfilled
        bool withdraw;
        uint256 next;
    }
    struct Trade {
        uint256 amount;
        uint256 price;
    }

    uint256 public autoMatch = 10;
    uint256 public makeFeeRate = 0;
    uint256 public takeFeeRate = 2 * (10 ** 16);
    uint256 public maxAmount = 10 ** 27;
    uint256 public minAmount = 10 ** 16;
    uint256 private orderNumber = 0;
    mapping(uint256 => Order) public orderBooks;
    mapping(bytes32 => Trade[]) public tradeBooks;
    mapping(address => mapping(address => uint256)) public balance;
    mapping(bytes32 => uint256) private bestOrder;

    event Deposit(address user, address token, uint256 amount, address operator);
    event Withdraw(address user, address token, uint256 amount, address operator);
    event Transfer(address user, address token, uint256 amount, address receiver, address operator);
    event MakeOrder(uint256 no, address user, address fromToken, uint256 fromAmount, address toToken, uint256 price);
    event UpdateOrder(uint256 no, uint256 filled, uint256 status);
    event MakeTrade(address fromToken, uint256 fromAmount, address toToken, uint256 toAmount);
    event Error(uint256 code);

    /* Owner Function
    */
    
    /* operator Function
    */

    /* External Function
        function () public payable;
        function deposit(address) public payable returns(bool);
        function withdraw(address, uint256) public returns(bool);
        function userMakeOrder(address, uint256, address, uint256, bool) public returns(uint256);
        function userTakeOrder(address, uint256, address, uint256, bool) public returns(uint256);
        function userCancelOrder(uint256) public returns(bool);
        function agentMakeOrder(address, uint256, address, uint256, bool, bytes32, bytes32, uint8) public returns(uint256);
        function agentTakeOrder(address, uint256, address, uint256, bool, bytes32, bytes32, uint8) public returns(uint256);
        function agentCancelOrder(uint256, bytes32, bytes32, uint8) public returns(bool);
        function trade(uint256) public returns(bool);
        function linkIndex(uint256, uint256) public returns(bool);
    */

    /* Internal Function
        function checkBalance(address, address, uint256) internal returns(bool);
        function checkAmount(uint256) internal returns(bool);
        function makeOrder(address, uint256, address, uint256, bool, address) internal returns(uint256);
        function makeIndex(address, uint256, address, uint256) internal returns(bool);
        function findAndTrade(uint256 taker_, uint256 maker_) internal returns(uint256);
        function makeTrade(uint256, uint256) internal returns(bool);
        function checkPair(uint256, uint256) internal returns(bool);
        function getOrderNumber() internal returns(uint256);
        function freeze(address, uint256) internal returns(bool);
        function changeStatus(uint256, uint8) internal;
        function removeIndex(uint256) internal returns(bool);
    */

    /* External function */
    function ()
        public
        payable
    {
        deposit(address(0));
    }

    // deposit all allowance
    function deposit(
        address token_
    )
        public
        payable
    returns(bool) {
        if(msg.value > 0) {
            balance[address(0)][msg.sender] = safeAdd(balance[address(0)][msg.sender], msg.value);
        }
        if(
            token_ != address(0)
        ) {
            uint amount = Token(token_).allowance(msg.sender, this);
            if(amount > 0) {
                Token(token_).transferFrom(msg.sender, this, amount);
                balance[token_][msg.sender] = safeAdd(balance[token_][msg.sender], amount);
            }
        }
        return true;
    }
    
    function withdraw(
        address token_,
        uint256 amount_
    )
        public
    returns(bool) {
        if(checkBalance(msg.sender, token_, amount_)) {
            if(token_ == address(0)) {
                balance[token_][msg.sender] = safeSub(balance[token_][msg.sender], amount_);
                msg.sender.transfer(amount_);
                return true;
            } else if(Token(token_).transfer(msg.sender, amount_)) {
                balance[token_][msg.sender] = safeSub(balance[token_][msg.sender], amount_);
                return true;
            }
        } else {
            return false;
        }
    }

    function userMakeOrder(
        address fromToken_,
        uint256 fromAmount_,
        address toToken_,
        uint256 price_,
        bool withdraw_
    )
        public
        payable
    returns(uint256) {
        // deposit -> makeOrder
        deposit(fromToken_);
        return makeOrder(fromToken_, fromAmount_, toToken_, price_, withdraw_, msg.sender);
    }

    function userTakeOrder(
        address fromToken_,
        uint256 fromAmount_,
        address toToken_,
        uint256 price_,
        bool withdraw_
    )
        public
        payable
    returns(uint256) {
        uint256 no = userMakeOrder(fromToken_, fromAmount_, toToken_, price_, withdraw_);
        trade(no);
        return no;
    }

    function userCancelOrder(
        uint256 no_
    )
        public
    returns(bool) {
        if(
            orderBooks[no_].user == msg.sender &&
            orderBooks[no_].status == 1
        ) {
            
        }
    }

    function agentMakeOrder(
        address fromToken_,
        uint256 fromAmount_,
        address toToken_,
        uint256 price_,
        bool withdraw_,
        bytes32 r_,
        bytes32 s_,
        uint8 v_
    )
        public
    returns(uint256) {
        bytes32 hash = keccak256(fromToken_, fromAmount_, toToken_, price_);
        address user = ecrecover(hash, v_, r_, s_);
        return makeOrder(fromToken_, fromAmount_, toToken_, price_, withdraw_, user);
    }

    function agentTakeOrder(address, uint256, address, uint256, bool, bytes32, bytes32, uint8) public returns(uint256) {}
    function agentCancelOrder(uint256, bytes32, bytes32, uint8) public returns(bool) {}

    function trade(
        uint256 taker_
    )
        public
    returns(bool) {
        bytes32 revertPairHash = keccak256(orderBooks[taker_].toToken, orderBooks[taker_].fromToken);
        uint256 maker = bestOrder[revertPairHash];
        if(
            maker > 0 &&
            safeMul(orderBooks[taker_].price, orderBooks[maker].price) > 1
        ) {
            findAndTrade(taker_, maker, autoMatch);
        }
    }

    function linkIndex(
        uint256 no_,
        uint256 prev_
    )
        public
    returns(bool) {
        uint256 curr = orderBooks[prev_].next;
        uint256 price = orderBooks[no_].price;
        if(curr == 0 || price > orderBooks[curr].price) {
            orderBooks[no_].next = curr;
            orderBooks[prev_].next = no_;
            return true;
        } else {
            return linkIndex(no_, curr);
        }
    }
    
    /* Internal Function */
    function checkBalance(
        address user_,
        address token_,
        uint256 amount_
    )
        internal
    returns(bool) {
        if(balance[token_][user_] < amount_) {
            Error(0);
            return false;
        } else {
            return true;
        }
    }
    
    function checkAmount(
        uint256 amount_
    )
        internal
    returns(bool) {
        if(amount_ > maxAmount) {
            Error(2);
            return false;
        } else if(amount_ < minAmount) {
            Error(3);
            return false;
        }
        return true;
    }

    function makeOrder(
        address fromToken_,
        uint256 fromAmount_,
        address toToken_,
        uint256 price_,
        bool withdraw_,
        address user_
    )
        internal
    returns(uint256) {
        if(
            checkAmount(fromAmount_) &&
            freeze(user_, fromToken_, fromAmount_)
        ) {
            uint256 no = getOrderNumber();
            orderBooks[no] = Order(user_, fromToken_, fromAmount_, toToken_, price_, 0, 1, withdraw_, 0);
            makeIndex(no);
            MakeOrder(no, user_, fromToken_, fromAmount_, toToken_, price_);
            return no;
        }
    }

    function makeIndex(
        uint256 no_
    )
        internal
    returns(bool) {
        bytes32 pairHash = keccak256(orderBooks[no_].fromToken, orderBooks[no_].toToken);
        uint256 price = orderBooks[no_].price;
        if(bestOrder[pairHash] == 0) {
            bestOrder[pairHash] = no_;
        } else if(price > orderBooks[bestOrder[pairHash]].price) {
            orderBooks[no_].next = bestOrder[pairHash];
            bestOrder[pairHash] = no_;
        } else {
            linkIndex(no_, bestOrder[pairHash]);
        }
    }

    // transfer to Taker in one time after all makeTrade
    function findAndTrade(
        uint256 taker_,
        uint256 maker_,
        uint256 counts_
    )
        internal
    returns(uint256) {
        uint256 totalAmount = 0;
        for(uint i = 0; i <= counts_; i++) {
            uint256 amount = makeTrade(taker_, maker_);
            totalAmount = safeAdd(totalAmount, amount);
            if(
                amount == 0 ||
                orderBooks[maker_].next == 0 ||
                orderBooks[taker_].fromAmount == orderBooks[taker_].filled
            ) {
                break;
            }
        }
        return totalAmount;
    }

    function checkTradePair(
        uint256 taker_,
        uint256 maker_
    )
        internal
    returns(bool) {
        return (
            orderBooks[taker_].fromToken == orderBooks[maker_].toToken &&
            orderBooks[taker_].toToken == orderBooks[maker_].fromToken &&
            safeMul(orderBooks[taker_].price, orderBooks[maker_].price) > 0 &&
            orderBooks[taker_].status == 1 &&
            orderBooks[maker_].status == 1 &&
            orderBooks[taker_].fromAmount > orderBooks[taker_].filled &&
            orderBooks[maker_].fromAmount > orderBooks[maker_].filled
        );
    }

    function makeTrade(
        uint256 taker_,
        uint256 maker_
    )
        internal
    returns(uint256) {
        if(
            checkTradePair(taker_, maker_)
        ) {
            
        } else {
            
        }
    }

    function getOrderNumber()
        public
    returns(uint256) {
        uint256 result = ++orderNumber > 0 ? orderNumber : ++orderNumber;
        return result;
    }
    
    function freeze(
        address user_,
        address token_,
        uint256 amount_
    )
        internal
    returns(bool) {
        if(checkBalance(user_, token_, amount_)) {
            balance[token_][user_] = safeSub(balance[token_][user_], amount_);
            return true;
        } else {
            return false;
        }
    }

    function findPrev(
        uint256 no_,
        uint256 seek_
    )
        internal
    returns(uint256) {
        uint256 next = orderBooks[seek_].next;
        if(next == no_) {
            return no_;
        } else {
            return findPrev(no_, next);
        }
    }
    
    function removeIndex(
        uint256 no_
    )
        public
    returns(bool) {
        bytes32 pairHash = keccak256(orderBooks[no_].fromToken, orderBooks[no_].toToken);
        uint256 prev = findPrev(no_, bestOrder[pairHash]);
        uint256 next = orderBooks[no_].next;
        orderBooks[prev].next = next;
        if(next > 0) {
            orderBooks[no_].next = 0;
        }
    }
}