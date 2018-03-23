pragma solidity ^0.4.18;

contract Authorization {
    bool internal active = true;
    address public owner;
    mapping(address => bool) internal authbook;
    address[] public operators;

    function Authorization()
        public
    {
        owner = msg.sender;
    }

    modifier onlyOwner
    {
        assert(msg.sender == owner);
        _;
    }
    modifier onlyOperator
    {
        assert(checkOperator(msg.sender));
        _;
    }
    modifier onlyActive
    {
        assert(usable());
        _;
    }

    function transferOwnership(address newOwner_)
        onlyOwner
        public
    {
        owner = newOwner_;
    }
    
    function assignOperator(address user_)
        public
        onlyOwner
    {
        if(user_ != address(0) && !authbook[user_]) {
            authbook[user_] = true;
            operators.push(user_);
        }
    }
    
    function dismissOperator(address user_)
        public
        onlyOwner
    {
        delete authbook[user_];
        for(uint i = 0; i < operators.length; i++) {
            if(operators[i] == user_) {
                operators[i] = operators[operators.length - 1];
                operators.length -= 1;
            }
        }
    }
    
    function checkOperator(address user_)
        public
        view
    returns(bool) {
        return authbook[user_];
    }
    
    function usable()
        public
        view
    returns(bool) {
        return active;
    }
    
    function lock()
        public
        onlyOperator
    {
        if(active) {
            active = false;
        }
    }

    function unlock()
        public
        onlyOperator
    {
        if(!active) {
            active = true;
        }
    }
}