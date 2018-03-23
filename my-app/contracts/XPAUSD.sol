pragma solidity ^0.4.20;


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
interface Baliv {
    function priceBooks(address _from, address _to) public returns (uint256 price);
}
contract SafeMath {
    function safeAdd(uint x, uint y)
        internal
        pure
    returns(uint) {
      uint256 z = x + y;
      require((z >= x) && (z >= y));
      return z;
    }

    function safeSub(uint x, uint y)
        internal
        pure
    returns(uint) {
      require(x >= y);
      uint256 z = x - y;
      return z;
    }

    function safeMul(uint x, uint y)
        internal
        pure
    returns(uint) {
      uint z = x * y;
      require((x == 0) || (z / x == y));
      return z;
    }
    
    function safeDiv(uint x, uint y)
        internal
        pure
    returns(uint) {
        require(y > 0);
        return x / y;
    }

    function random(uint N, uint salt)
        internal
        view
    returns(uint) {
      bytes32 hash = keccak256(block.number, msg.sender, salt);
      return uint(hash) % N;
    }
}

contract Authorization {
    bool internal active = true;
    address public owner;
    address public operator;

    function Authorization()
        public
    {
        owner = msg.sender;
        operator = msg.sender;
    }

    modifier onlyOwner
    {
        assert(msg.sender == owner);
        _;
    }
    modifier onlyOperator
    {
        assert(msg.sender == operator || msg.sender == owner);
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
        operator = user_;
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

contract StandardToken is SafeMath, Authorization {
    uint256 public totalSupply;
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    
    /* constructure */
    function StandardToken() public payable {}

    /* Send coins */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] = safeSub(balances[msg.sender], _value);
            balances[_to] = safeAdd(balances[_to], _value);
            Transfer(msg.sender, _to, _value);
            return true;
        } else {
            return false;
        }
    }

    /* A contract attempts to get the coins */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] = safeAdd(balances[_to], _value);
            balances[_from] = safeSub(balances[_from], _value);
            allowed[_from][msg.sender] = safeSub(allowed[_from][msg.sender], _value);
            Transfer(_from, _to, _value);
            return true;
        } else {
            return false;
        }
    }

    function balanceOf(address _owner) constant public returns (uint256 balance) {
        return balances[_owner];
    }

    /* Allow another contract to spend some tokens in your behalf */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        assert((_value == 0) || (allowed[msg.sender][_spender] == 0));
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant public returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    /* This creates an array with all balances */
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
}

contract XPAUSD is StandardToken {
    // metadata
    struct Order {
        uint256 fromAmount;
        uint256 toAmount;
    }

    string public constant name = "XPAUSD token";
    string public constant symbol = "USX";
    string public version = "1.0";
    uint256 public constant decimals = 18;

    // contracts
    address public baliv;
    address public XPA;

    // XPAMortgage
    uint256 public defaultExchangeRate = 0.01 ether; // XPA/USX default exchange rate
    uint256 public lowestMortgageRate = 0.5 ether; 
    uint256 public closingLine = 0.4 ether;
    
    // events
    event eMortgage(address user, uint256 amount);
    event eWithDraw(address user, uint256 amount);
    event eRepayment(address user, uint256 amount);
    
    //data
    mapping(address => Order) public books;
    uint256 public profit = 0;
    
    //fee
    uint256 public withDrawFeeRate = 0.02 ether; // 提領手續費
    uint256 public offsetFeeRate = 0.02 ether;   // 平倉手續費
    uint256 public mandatoryOffsetBasicFeeRate = 0.02 ether; // 強制平倉基本費
    uint256 public mandatoryOffsetExcuteFeeRate = 0.01 ether;// 強制平倉執行費
    uint256 public mandatoryOffsetExtraFeeRate = 0.05 ether; // 強制平倉額外手續費
    
    // constructor
    function XPAUSD(
        address Baliv_,
        address XPA_,
        address operator_
    )
        payable
        public
    {
        XPA = XPA_;
        baliv = Baliv_;
        assignOperator(operator_);
    }
    
    //抵押 XPA
    function mortgage()
        public
    {
        uint256 amount_ = Token(XPA).allowance(msg.sender, this); //allowance is mortgage amount
        require(Token(XPA).transferFrom(msg.sender, this, amount_));
        books[msg.sender].fromAmount = safeAdd(books[msg.sender].fromAmount, amount_);
        eMortgage(msg.sender,amount_);
    }
    
    // 借出 USX, amount: 指定借出金額
    function withDraw(
        uint256 amount_
    ) 
        public 
    returns(bool){
        if(
            checkWithDraw(amount_)
        ){
            totalSupply = safeAdd(totalSupply, amount_);
            uint256 withDrawFee = amount_ * withDrawFeeRate / 1 ether;
            balances[this] = safeAdd(balances[this], withDrawFee);
            balances[msg.sender] = safeAdd(balances[msg.sender], amount_ - withDrawFee);
            books[msg.sender].toAmount = safeAdd(books[msg.sender].toAmount,amount_);
            eWithDraw(msg.sender,amount_);
        }
    }
    
    function checkWithDraw(
        uint256 amount_
    ) 
        public 
    returns(bool) {
        uint256 fromAmount = books[msg.sender].fromAmount;
        uint256 toAmount = books[msg.sender].toAmount;
        
        uint256 price = getPrice();
        uint256 maxToAmount = ((fromAmount * price) / 1 ether * ( 1 ether - lowestMortgageRate) / 1 ether);
        if(amount_ <= safeSub(maxToAmount,toAmount)){
            return true;
        }else{
            return false;
        }
    }
    
    // 還款 USX, amount: 指定還回金額
    function repayment(
        uint256 amount_
    )
        public
    {
        if(
            burn(amount_)
        ){
            books[msg.sender].toAmount = safeSub(books[msg.sender].toAmount,amount_);
            eRepayment(msg.sender,amount_);
        }
    }
    
    function burn(
        uint256 amount_
    )
        internal
    returns(bool) {
        if(balances[msg.sender] >= amount_) {
            balances[msg.sender] = safeSub(balances[msg.sender], amount_);
            totalSupply = safeSub(totalSupply, amount_);
            return true;
        }else{
            return false;
        }
    }

    // 取得用戶抵押率, user: 指定用戶
    function getMortgageRate(
        address user
    ) 
        public 
    returns(uint256){
        uint256 price = getPrice();
        uint256 x = books[user].fromAmount * price/ 1 ether;
        return (x - books[user].toAmount) / x * 1 ether;
    }
        
    // 取得最低抵押率
    function getLowestMortgageRate() 
        public 
    returns(uint256){
        return lowestMortgageRate;
    }
    
    // 取得平倉線
    function getClosingLine() 
        public 
    returns(uint256){
        return closingLine;
    }
    
    // 取得 XPA -> USX 匯率
    function getPrice() 
        public 
    returns(uint256){
        uint256 price = Baliv(baliv).priceBooks(XPA, this);
        if(price == 0){
            price = defaultExchangeRate;
        }
        return price;
    }
    
    // 取得用戶已抵押 XPA 等值 USX 數量, user: 指定用戶
    function getEquivalentAmount(
        address user
    ) 
        public
    returns(uint256) {
        uint256 price = getPrice();
        return books[user].fromAmount * price / 1 ether;
    }
    
    // 取得用戶可借貸 USX 額度, user: 指定用戶
    function getUsableAmount(
        address user
    ) 
        public
    returns(uint256) {
        uint256 fromAmount = books[user].fromAmount;
        uint256 price = getPrice();
        return ((fromAmount * price) / 1 ether * ( 1 ether - lowestMortgageRate) / 1 ether);
    }
    
    // 取得用戶已借貸 USX 數量, user: 指定用戶
    function getLoanAmount(
        address user
    ) 
        public
    returns(uint256) {
        return books[user].toAmount;
    }
    
    // 取得用戶剩餘可借貸 USX 額度, user: 指定用戶
    function getRemainingAmount(
        address user
    ) 
        public
    returns(uint256) {
        if(
            getUsableAmount(user) >= getLoanAmount(user)
        ){
            return getUsableAmount(user) - getLoanAmount(user);
        }else{
            return 0;
        }
        
    }
    
    function setWithDrawFeeRate(
        uint256 feerate_
    )
        onlyOperator
        public
    {
        require(feerate_ < 0.05 ether);
            withDrawFeeRate = feerate_;
    }
    
    function setOffsetFeeRate(
        uint256 feerate_
    )
        onlyOperator
        public
    {
        require(feerate_ < 0.05 ether);
            offsetFeeRate = feerate_;
    }
    
    function setMandatoryOffsetBasicFeeRate(
        uint256 feerate_
    )
        onlyOperator
        public
    {
        require(feerate_ < 0.05 ether);
            mandatoryOffsetBasicFeeRate = feerate_;
    }
    
    function setMandatoryOffsetExcuteFeeRate(
        uint256 feerate_
    )
        onlyOperator
        public
    {
        require(feerate_ < 0.05 ether);
            mandatoryOffsetExcuteFeeRate = feerate_;
    }
    
    function setMandatoryOffsetExtraFeeRate(
        uint256 feerate_
    )
        onlyOperator
        public
    {
        require(feerate_ < 0.5 ether);
            mandatoryOffsetExtraFeeRate = feerate_;
    }
}