pragma solidity ^0.4.17;

contract MyApp {
    string public textMessage;

    function MyApp(string initialTextMessage) public {
        textMessage = initialTextMessage;
    }

    function setTextMessage(string newText) public {
        textMessage = newText;
    }
}
