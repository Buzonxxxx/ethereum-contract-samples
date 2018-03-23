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

interface Bank {
    function depositToFreeze(address user_, address token_, uint256 amount_) public payable returns(bool);
    function withdrawFromFreeze(address user_, address token_, uint256 amount_) public returns(bool);
    function transferFromFreeze(address user_, address token_, uint256 amount_, address receiver_) public returns(bool);
}

contract XPAExchange is SafeMath, Authorization {
    struct Order {
        uint256 no;
        address user;
        address fromToken;
        uint256 fromAmount;
        address toToken;
        uint256 toAmount;
        uint256 filled;
        uint256 expire;
        uint256 orderType;  // 0: limit(maker), 1: market(taker), 2: stop-loss
        uint256 status;     // 0: cancel, 1: active, 2: expire
    }

    uint256 private orderNumber = 0;
    uint256 public timeout = 40000;
    address private bank;
    mapping(uint256 => Order) public orderBooks;
    mapping(address => mapping(address => uint256)) internal priceBooks;

    event MakeOrder(uint256 no, address user, address fromToken, uint256 fromAmount, address toToken, uint256 toAmount);
    event TakeOrder(uint256 no, address user, address fromToken, uint256 fromAmount, address toToken, uint256 toAmount);
    event UpdateOrder(uint256 no, uint256 filled, uint256 status);
    event MakeTrade(address fromToken, uint256 fromAmount, address toToken, uint256 toAmount);

    function XPAExchange(
        address operator_,
        address bank_
    )
        public
    {
        assignOperator(operator_);
        bank = bank_;
    }

    function checkAmount(
        uint256 amount_
    )
        internal
        pure
    returns(bool) {
        return amount_ > (10 ** 9) && amount_ <= (10 ** 27);
    }

    function safeCalcRatio(
        uint256 fromAmount_,
        uint256 toAmount_
    )
        internal
        pure
    returns(uint256) {
        require(checkAmount(fromAmount_) && checkAmount(toAmount_));
        return fromAmount_ * (10 ** 18) / toAmount_;
    }

    function safeNeed(
        uint256 fromAmount_,
        uint256 toAmount_,
        uint256 filled
    )
        internal
        pure
    returns(uint256) {
        require(
            checkAmount(fromAmount_) &&
            checkAmount(toAmount_)
        );
        uint256 toNeed = safeCalcRatio(toAmount_, fromAmount_) * safeSub(fromAmount_, filled) / (10**18);
        return toNeed;
    }
    
    function checkPair(
        Order orderMake_,
        Order orderTake_
    )
        internal
        pure
    returns(bool) {
        return (
            orderMake_.status == 1 &&
            orderTake_.status == 1 &&
            orderMake_.fromToken == orderTake_.toToken &&
            orderMake_.toToken == orderTake_.fromToken &&
            orderMake_.fromAmount > orderMake_.filled &&
            orderTake_.fromAmount > orderTake_.filled
        );
    }

    function userMakeOrder(
        address fromToken_,
        uint256 fromAmount_,
        address toToken_,
        uint256 toAmount_
    )
        public
        payable
    {
        require(
            active &&
            checkAmount(fromAmount_) &&
            checkAmount(toAmount_)
        );
        if(fromToken_ == 0x0000000000000000000000000000000000000000) {
            require(msg.value >= fromAmount_);
            require(Bank(bank).depositToFreeze.value(msg.value)(msg.sender, fromToken_, fromAmount_));
        } else {
            require(Token(fromToken_).transferFrom(msg.sender, this, fromAmount_));
            require(Token(fromToken_).approve(bank, fromAmount_));
            require(Bank(bank).depositToFreeze(msg.sender, fromToken_, fromAmount_));
        }
        orderBooks[orderNumber] = Order(orderNumber, msg.sender, fromToken_, fromAmount_, toToken_, toAmount_, 0, timeout, 0, 1);
        MakeOrder(orderNumber, msg.sender, fromToken_, fromAmount_, toToken_, toAmount_);
        orderNumber++;
    }

    function userTakeOrder(
        address fromToken_,
        uint256 fromAmount_,
        address toToken_,
        uint256 toAmount_,
        uint256[] txnos_
    )
        public
        payable
    {
        require(
            active &&
            checkAmount(fromAmount_) &&
            checkAmount(toAmount_)
        );
        if(fromToken_ == 0x0000000000000000000000000000000000000000) {
            require(msg.value >= fromAmount_);
            require(Bank(bank).depositToFreeze.value(msg.value)(msg.sender, fromToken_, fromAmount_));
        } else {
            require(Token(fromToken_).transferFrom(msg.sender, this, fromAmount_));
            require(Token(fromToken_).approve(bank, fromAmount_));
            require(Bank(bank).depositToFreeze(msg.sender, fromToken_, fromAmount_));
        }
        
        uint256 length = txnos_.length;
        uint256 thisOrder = orderNumber;
        orderBooks[orderNumber] = Order(orderNumber, msg.sender, fromToken_, fromAmount_, toToken_, toAmount_, 0, timeout, 1, 1);
        TakeOrder(orderNumber, msg.sender, fromToken_, fromAmount_, toToken_, toAmount_);
        for(uint i = 0; i < length; i++) {
            userMakeTrade(txnos_[i], thisOrder);
        }
        orderNumber++;
    }

    function userMakeTrade(
        uint256 make_,
        uint256 take_
    )
        private
    returns(bool) {
        Order storage orderMake = orderBooks[make_];
        Order storage orderTake = orderBooks[take_];
        uint256 makeNeed = safeNeed(orderMake.fromAmount, orderMake.toAmount, orderMake.filled);
        uint256 makeProvide = safeSub(orderMake.fromAmount, orderMake.filled);
        uint256 takeNeed = safeNeed(orderTake.fromAmount, orderTake.toAmount, orderTake.filled);
        uint256 takeProvide = safeSub(orderTake.fromAmount, orderTake.filled);
        uint256 makeFill = orderMake.filled;
        uint256 takeFill = orderTake.filled;
        uint256 premium = 0;

        require(
            checkPair(orderMake, orderTake) &&
            orderMake.fromAmount * orderTake.fromAmount / orderMake.toAmount / orderTake.toAmount >= 1
        );

        if(makeNeed >= safeSub(orderTake.fromAmount, orderTake.filled)) {
            premium = getPremium(takeProvide, orderMake.fromAmount, orderMake.toAmount, orderTake.fromAmount, orderTake.toAmount);
            takeFill = safeSub(orderTake.fromAmount, takeFill);
            require(
                Bank(bank).transferFromFreeze(orderMake.user, orderMake.fromToken, takeNeed, orderTake.user) &&
                Bank(bank).withdrawFromFreeze(orderTake.user, orderTake.toToken, takeNeed) &&
                Bank(bank).transferFromFreeze(orderTake.user, orderTake.fromToken, takeProvide, orderMake.user) &&
                Bank(bank).withdrawFromFreeze(orderMake.user, orderMake.toToken, takeProvide) &&
                Bank(bank).transferFromFreeze(orderTake.user, orderTake.fromToken, premium, this)
            );

            orderMake.filled = safeAdd(orderMake.filled, safeAdd(takeNeed, premium));
            orderTake.filled = orderTake.fromAmount;
            MakeTrade(orderTake.fromToken, takeFill, orderTake.toToken, takeNeed);
            UpdateOrder(orderMake.no, orderMake.filled, orderMake.status);
            UpdateOrder(orderTake.no, orderTake.filled, orderTake.status);
        } else {
            premium = getPremium(makeNeed, orderMake.fromAmount, orderMake.toAmount, orderTake.fromAmount, orderTake.toAmount);
            makeFill = safeSub(orderMake.fromAmount, makeFill);
            require(
                Bank(bank).transferFromFreeze(orderMake.user, orderMake.fromToken, safeSub(makeProvide, premium), orderTake.user) &&
                Bank(bank).withdrawFromFreeze(orderTake.user, orderTake.toToken, safeSub(makeProvide, premium)) &&
                Bank(bank).transferFromFreeze(orderTake.user, orderTake.fromToken, makeNeed, orderMake.user) &&
                Bank(bank).withdrawFromFreeze(orderMake.user, orderMake.toToken, makeNeed) &&
                Bank(bank).transferFromFreeze(orderTake.user, orderTake.fromToken, premium, this)
            );
            
            orderMake.filled = orderMake.fromAmount;
            orderTake.filled = safeAdd(orderTake.filled, makeNeed);
            MakeTrade(orderTake.fromToken, makeNeed, orderTake.toToken, makeFill);
            UpdateOrder(orderMake.no, orderMake.filled, orderMake.status);
            UpdateOrder(orderTake.no, orderTake.filled, orderTake.status);
        }

        priceBooks[orderTake.fromToken][orderTake.toToken] = safeCalcRatio(orderTake.toAmount, orderTake.fromAmount);
        priceBooks[orderTake.toToken][orderTake.fromToken] = safeCalcRatio(orderTake.fromAmount, orderTake.toAmount);
        return true;
    }

    function getPrice(
        address fromToken_,
        address toToken_
    )
        public
        view
    returns(uint256) {
        return priceBooks[fromToken_][toToken_];
    }

    function userCancelOrder(
        uint256 no_
    )
        public
    {
        require(
            orderBooks[no_].status == 1 &&
            msg.sender == orderBooks[no_].user
        );

        uint256 returnAmount = safeSub(orderBooks[no_].fromAmount, orderBooks[no_].filled);
        require(Bank(bank).withdrawFromFreeze(msg.sender, orderBooks[no_].fromToken, returnAmount));

        orderBooks[no_].status = 0;
        UpdateOrder(no_, orderBooks[no_].filled, orderBooks[no_].status);
    }
    
    function getPremium(
        uint256 amount_,
        uint256 makeFromAmount_,
        uint256 makeToAmount_,
        uint256 takeFromAmount_,
        uint256 takeToAmount_
    )
        internal
        pure
    returns(uint256) {
        return amount_ * makeFromAmount_ / makeToAmount_ * ((10 ** 18) - (makeToAmount_ * (10 ** 18) / makeFromAmount_ * takeToAmount_ / takeFromAmount_)) / (10 ** 18);
    }

    function setBank(
        address bank_
    )
        public
        onlyOperator
    {
        bank = bank_;
    }
}