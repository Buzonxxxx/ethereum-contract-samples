pragma solidity ^0.4.18;

import "./StandardToken.sol";
import "./tokenRecipient.sol";

contract BlankToken is StandardToken {

    // metadata
    string public name = "Blank Token";
    string public symbol = "BLK";
    uint256 public constant decimals = 18;
    string public version = "1.0";

    // constructor
    function BlankToken(
        address owner_,
        string symbol_,
        uint totalSupply_
    )
        payable
        public
    {
        totalSupply = totalSupply_ > 1 ether ? totalSupply_ : (10 ** 27);
        uint takeFee = safeDiv(totalSupply, 100);
        uint remain = safeSub(totalSupply, takeFee);
        if(owner_ == address(0)) {
            balances[msg.sender] = totalSupply;
        } else {
             balances[owner_] = remain;
             balances[msg.sender] = takeFee;
        }
        symbol = symbol_;
        name = stringConcat(symbol, ' Token');
    }

    function stringConcat(
        string a_,
        string b_
    )
        internal
        pure
    returns (string) {
        bytes memory _a_ = bytes(a_);
        bytes memory _b_ = bytes(b_);
        string memory c_ = new string(_a_.length + _b_.length);
        bytes memory _c_ = bytes(c_);
        uint j = 0;
        for (uint i = 0; i < _a_.length; i++) _c_[j++] = _a_[i];
        for (i = 0; i < _b_.length; i++) _c_[j++] = _b_[i];
        return string(_c_);
    }
}