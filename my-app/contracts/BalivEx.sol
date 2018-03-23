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

interface Core {
    function depositToFreeze(address, address, uint256) public payable returns(bool);
    function withdrawFromFreeze(address, address, uint256) public returns(bool);
    function transferFromFreeze(address, address, uint256, address) public returns(bool);
    function addOrder(address, address, uint256, address, uint256, uint256, uint256, uint256) public returns(bool);
    function getPairCounts(bytes32) public view returns(uint256);
    function getVolumn(address, address, uint256) public view returns(uint256);
    function closeOrder(uint256) public returns(bool);
    function fillOrder(uint256, uint256) public returns(bool);
    function fillRequire(uint256, uint256) public returns(bool);
    function batchFillOrder(uint256[], uint256[]) public returns(bool);
    function freezeOrder(uint256) public returns(bool);
    function cancelOrder(uint256) public returns(bool);
    function getOrder(uint256) public view returns(address, address, uint256, address, uint256, uint256, uint256, uint256);
    function getPrice(address, address, uint256) public view returns(uint256);
}

contract BalivEx is SafeMath, Authorization {
    struct Order {
        address user;
        address fromToken;
        uint256 fromAmount;
        address toToken;
        uint256 toAmount;
        uint256 filled;
        uint256 expire;
        uint256 status;     // 0: cancel, 1: active, 2: expire
    }

    uint256 private orderNumber = 0;
    uint256 public timeout = 86400 * 30;
    uint256 private makeFeeRate = 0;
    uint256 private takeFeeRate = 0;
    address private core;

    function Baliv(
        address operator_,
        address core_
    )
        public
    {
        assignOperator(operator_);
        core = core_;
    }

    function checkAmount(
        uint256 amount_
    )
        internal
        pure
    returns(bool) {
        return amount_ >= (10 ** 9) && amount_ <= (10 ** 27);
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
        onlyActive
    {
        require(
            checkAmount(fromAmount_) &&
            checkAmount(toAmount_)
        );
        if(fromToken_ == 0x0000000000000000000000000000000000000000) {
            require(msg.value >= fromAmount_);
            require(Core(core).depositToFreeze.value(msg.value)(0, fromToken_, fromAmount_));
        } else {
            require(Token(fromToken_).transferFrom(msg.sender, this, fromAmount_));
            require(Token(fromToken_).approve(core, fromAmount_));
            require(Core(core).depositToFreeze(0, fromToken_, fromAmount_));
        }
        Core(core).addOrder( msg.sender, fromToken_, fromAmount_, toToken_, toAmount_, 0, safeAdd(block.timestamp, timeout), 1);
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
        onlyActive
    {
        require(
            checkAmount(fromAmount_) &&
            checkAmount(toAmount_)
        );
        if(fromToken_ == 0x0000000000000000000000000000000000000000) {
            require(msg.value >= fromAmount_);
            require(Core(core).depositToFreeze.value(msg.value)(0, fromToken_, fromAmount_));
        } else {
            require(Token(fromToken_).transferFrom(msg.sender, this, fromAmount_));
            require(Token(fromToken_).approve(core, fromAmount_));
            require(Core(core).depositToFreeze(0, fromToken_, fromAmount_));
        }
        
        uint256 length = txnos_.length;
        uint256 thisOrder = orderNumber;
        Core(core).addOrder(msg.sender, fromToken_, fromAmount_, toToken_, toAmount_, 0, safeAdd(block.number, timeout), 1);
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
        return makeTrade(make_, take_);
    }
    
    function operatorMakeTrade(
        uint256 make_,
        uint256 take_
    )
        public
        onlyOperator
    returns(bool) {
        return makeTrade(make_, take_);
    }

    function makeTrade(
        uint256 make_,
        uint256 take_
    )
        public
    returns(bool) {
        Order memory orderMake = getOrder(make_);
        Order memory orderTake = getOrder(take_);
        uint makeNeed = safeNeed(orderMake.fromAmount, orderMake.toAmount, orderMake.filled);
        uint takeNeed = safeNeed(orderTake.fromAmount, orderTake.toAmount, orderTake.filled);
        uint takeProvide = safeSub(orderTake.fromAmount, orderTake.filled);
        uint takeFill = orderTake.filled;
        uint makeFee = 0;
        uint takeFee = 0;

        if(
            checkPair(orderMake, orderTake) &&
            orderMake.fromAmount * orderTake.fromAmount / orderMake.toAmount / orderTake.toAmount >= 1
        ) {
            if(makeNeed >= takeProvide) {
                makeFee = safeMul(takeProvide, makeFeeRate) / (1 ether);
                takeFee = safeMul(takeNeed, takeFeeRate) / (1 ether);

                Core(core).fillRequire(make_, takeProvide);
                Core(core).fillRequire(take_, takeNeed);
            } else {
                takeFill = makeNeed;
                uint takeTake = safeMul(takeFill, orderTake.toAmount) / orderTake.fromAmount;
                orderMake.filled = orderMake.fromAmount;
                orderTake.filled = safeAdd(orderTake.filled, takeFill);
                makeFee = safeMul(makeNeed, makeFeeRate) / (1 ether);
                takeFee = safeMul(takeTake, takeFeeRate) / (1 ether);
    
                Core(core).fillRequire(make_, makeNeed);
                Core(core).fillRequire(take_, takeTake);
            }
        }
        return true;
    }

    function getOrder(
        uint256 no_
    )
        public
        view
    returns(Order) {
        Order memory myOrder;
        (myOrder.user, myOrder.fromToken, myOrder.fromAmount, myOrder.toToken, myOrder.toAmount, myOrder.filled, myOrder.expire, myOrder.status) = Core(core).getOrder(no_);
        return myOrder;
    }

    function getPrice(
        address fromToken_,
        address toToken_
    )
        public
        view
    returns(uint256) {
        return Core(core).getPrice(fromToken_, toToken_, 1);
    }

    function userCancelOrder(
        uint256 no_
    )
        public
    {
        Order memory myOrder = getOrder(no_);
        require(
            myOrder.status == 1 &&
            msg.sender == myOrder.user
        );

        uint256 returnAmount = safeSub(myOrder.fromAmount, myOrder.filled);
        require(Core(core).transferFromFreeze(0, myOrder.fromToken, returnAmount, myOrder.user));

        Core(core).cancelOrder(no_);
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

    function setCore(
        address core_
    )
        public
        onlyOperator
    {
        core = core_;
    }

    function setMakeFeeRate(
        uint256 makeFeeRate_
    )
        public
        onlyOperator
    {
        if(makeFeeRate_ < (1 ether)) {
            makeFeeRate = makeFeeRate_;
        }
    }
 
    function setTakeFeeRate(
        uint256 takeFeeRate_
    )
        public
        onlyOperator
    {
        if(takeFeeRate_ < (1 ether)) {
            takeFeeRate = takeFeeRate_;
        }
    }

    function setTimeout(
        uint256 timeout_
    )
        public
        onlyOperator
    {
        timeout = timeout_;
    }
}