pragma solidity ^0.4.17;

contract Lottery {
    address public manager;
    address[] public players;
    
    constructor() public {
        manager = msg.sender;
    }
    
    function enter() public payable {
        require(msg.value > .01 ether);
        players.push(msg.sender);
    }
    
    function random() private view returns(uint) {
        // keccak256: compute the Ethereum-SHA-3 (Keccak-256) hash of the (tightly packed) arguments
        return uint(keccak256(abi.encodePacked(block.difficulty, now, players)));
    }
    
    function pickWinner() public restricted {
        uint index = random() % players.length;
        //players[index] = 0xafk323523523llhg4
        players[index].transfer(this.balance);
        //reset state, initial size is 0
        players = new address[](0); 
    }
    
    modifier restricted() {
        require(msg.sender == manager);
        _;
    }
    
    function getPlayers() public view returns(address[]) {
        return players;
    }
}