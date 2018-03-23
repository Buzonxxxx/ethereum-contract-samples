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

contract BalivCore is SafeMath, Authorization {
    struct Order {
        address user;
        address fromToken;
        uint256 fromAmount;
        address toToken;
        uint256 toAmount;
        uint256 filled;
        uint256 expire;
        uint256 status;     // 0: cancel, 1: active, 2: freeze
    }
    struct Trade {
        uint256 fromAmount;
        uint256 toAmount;
    }
    struct Account {
        mapping(address => uint256) balance;
        mapping(address => uint256) freeze;
    }
    
    uint256 public orderNumber = 0;
    mapping(bytes32 => uint256[]) public pairIndex;
    mapping(bytes32 => uint256) public pairVolumn;
    mapping(uint256 => Order) public orderBooks;
    mapping(bytes32 => Trade[]) public tradeBooks;
    mapping(address => bool) public tokenVerification;
    mapping(address => Account) private accounts;
    address[] public tokenList;

    event MakeOrder(uint256 no, address user, address fromToken, uint256 fromAmount, address toToken, uint256 toAmount);
    event UpdateOrder(uint256 no, uint256 filled, uint256 status);
    event MakeTrade(address fromToken, uint256 fromAmount, address toToken, uint256 toAmount);
    event Deposit(address user, address token, uint256 amount, address operator);
    event Withdraw(address user, address token, uint256 amount, address operator);
    event Transfer(address user, address token, uint256 amount, address receiver, address operator);

    function BalivCore(
        address operator_,
        address[] tokenList_
    )
        public
    {
        assignOperator(operator_);
        for(uint256 i = 0; i < tokenList_.length; i++) {
            addToken(tokenList_[i]);
        }
    }
    
    function addOrder(
        address user_,
        address fromToken_,
        uint256 fromAmount_,
        address toToken_,
        uint256 toAmount_,
        uint256 filled_,
        uint256 expire_,
        uint256 status_
    )
        public
        onlyOperator
    returns(bool) {
        bytes32 pairHash = keccak256(fromToken_, toToken_);
        orderBooks[orderNumber] = Order(user_, fromToken_, fromAmount_, toToken_, toAmount_, filled_, expire_, status_);
        pairIndex[pairHash].push(orderNumber);
        pairVolumn[pairHash] = safeSub(safeAdd(pairVolumn[pairHash], fromAmount_), filled_);
        MakeOrder(orderNumber, user_, fromToken_, fromAmount_, toToken_, toAmount_);
        orderNumber++;
        return true;
    }
    
    function getPairCounts(
        bytes32 pairHash_
    )
        public
        view
    returns(uint256) {
        return pairIndex[pairHash_].length;
    }
    
    function getVolumn(
        address fromToken_,
        address toToken_,
        uint256 price_
    )
        public
        view
    returns(uint256) {
        bytes32 pairHash = keccak256(fromToken_, toToken_);
        uint256 volumn = 0;
        uint256 l = getPairCounts(pairHash);
        if(!(l > 0)) {
            return volumn;
        } else {
            for(uint256 i = 0; i < l; i++) {
                if(
                    price_ == 0 ||
                    (orderBooks[pairIndex[pairHash][i]].toAmount * price_ / orderBooks[pairIndex[pairHash][i]].fromAmount) >= (10 ** 18)
                ) {
                    volumn = safeSub(safeAdd(volumn, orderBooks[pairIndex[pairHash][i]].fromAmount), orderBooks[pairIndex[pairHash][i]].filled);
                }
            }
            return volumn;
        }
    }
    
    function getPrice(
        address fromToken_,
        address toToken_,
        uint256 count_
    )
        public
        view
    returns(uint256) {
        bytes32 pairHash = keccak256(fromToken_, toToken_);
        uint256 count = count_ > 0 ? count_ : 1;
        uint256 fromAmount = 0;
        uint256 toAmount = 0;
        if(tradeBooks[pairHash].length > 0) {
            for(uint256 i = 0; i < count; i++) {
                fromAmount += tradeBooks[pairHash][tradeBooks[pairHash].length - 1].fromAmount;
                toAmount += tradeBooks[pairHash][tradeBooks[pairHash].length - 1].toAmount;
            }
            return toAmount * (1 ether) / fromAmount;
        } else {
            return 0;
        }
    }

    function getOrder(
        uint256 no_
    )
        public
        view
    returns(address, address, uint256, address, uint256, uint256, uint256, uint256) {
        Order memory myOrder = orderBooks[no_];
        return (myOrder.user, myOrder.fromToken, myOrder.fromAmount, myOrder.toToken, myOrder.toAmount, myOrder.filled, myOrder.expire, myOrder.status);
    }

    function closeOrder(
        uint256 no_
    )
        public
        onlyOperator
    returns(bool) {
        bytes32 pairHash = keccak256(orderBooks[no_].fromToken, orderBooks[no_].toToken);
        for(uint256 i = 0; i < pairIndex[pairHash].length; i++) {
            if(pairIndex[pairHash][i] == no_) {
                pairIndex[pairHash][i] = pairIndex[pairHash][pairIndex[pairHash].length - 1];
                pairIndex[pairHash].length -= 1;
                break;
            }
        }
        return true;
    }
    
    function fillOrder(
        uint256 no_,
        uint256 volumn_
    )
        public
        onlyOperator
    returns(bool) {
        bytes32 pairHash = keccak256(orderBooks[no_].fromToken, orderBooks[no_].toToken);
        uint256 newFilled = safeAdd(orderBooks[no_].filled, volumn_);
        uint256 toVolumn;
        if(newFilled > orderBooks[no_].fromAmount) {
            return false;
        }
        pairVolumn[pairHash] = safeSub(pairVolumn[pairHash], volumn_);
        orderBooks[no_].filled = newFilled;
        toVolumn = safeDiv(safeMul(volumn_, orderBooks[no_].toAmount), orderBooks[no_].fromAmount);
        tradeBooks[pairHash].push(
            Trade(volumn_, toVolumn)
        );
        if(safeSub(orderBooks[no_].fromAmount, orderBooks[no_].filled) <= (10 ** 9)) {
            closeOrder(no_);
        }
        UpdateOrder(no_, newFilled, orderBooks[no_].status);
        MakeTrade(orderBooks[no_].fromToken, volumn_, orderBooks[no_].toToken, toVolumn);
        return true;
    }
    
    function fillRequire(
        uint256 no_,
        uint256 volumn_
    )
        public
        onlyOperator
    returns(bool) {
        transferFromFreeze(0, orderBooks[no_].toToken, volumn_, orderBooks[no_].user);
        uint256 fill = safeMul(volumn_, orderBooks[no_].fromAmount) / orderBooks[no_].toAmount;
        return fillOrder(no_, fill);
    }
    
    function batchFillOrder(
        uint256[] no_,
        uint256[] volumn_
    )
        public
        onlyOperator
    returns(bool) {
        if(no_.length == volumn_.length) {
            for(uint256 i = 0; i < no_.length; i++) {
                fillOrder(no_[i], volumn_[i]);
            }
            return true;
        } else {
            return false;
        }
    }

    function freezeOrder(
        uint256 no_
    )
        public
        onlyOperator
    returns(bool) {
        if(orderBooks[no_].status != 2) {
            orderBooks[no_].status = 2;
        }
    }

    function cancelOrder(
        uint256 no_
    )
        public
        onlyOperator
    returns(bool) {
        if(orderBooks[no_].status != 0) {
            removeOrderVolumn(no_);
            orderBooks[no_].status = 0;
            closeOrder(no_);
            UpdateOrder(no_, orderBooks[no_].filled, 0);
        }
        return true;
    }
    
    function removeOrderVolumn(
        uint256 no_
    )
        internal
        onlyOperator
    returns(bool) {
        bytes32 pairHash = keccak256(orderBooks[no_].fromToken, orderBooks[no_].toToken);
        uint256 orderVolumn = safeSub(orderBooks[no_].fromAmount, orderBooks[no_].filled);
        if(orderVolumn > (10 ** 9)) {
            pairVolumn[pairHash] = safeSub(pairVolumn[pairHash], orderVolumn);
        }
    }
    
    function addToken(
        address token_
    )
        public
        onlyOperator
    returns(bool) {
        if(!tokenVerification[token_]) {
            tokenVerification[token_] = true;
            tokenList.push(token_);
            return true;
        }
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