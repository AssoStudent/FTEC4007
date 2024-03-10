// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

contract Lottery {
    address public owner;
    address payable[] private players;
    uint public lotteryId
    mapping (uint=>address payable) public lotteryHistory;

    constructor() {
        owner = msg.sender;
        lotteryId = 1;
    }


    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function getPlayers() public view returns (address payable[] memory) {
        return players;
    }

    function enter() public payable {
        require(msg.value > .01 ether);

        // address of player entering lottery
        players.push(payable(msg.sender));
        // Emit an event when a player enters the lottery
    }

    function getRandomNumber() private view returns (uint) {
        return uint(keccak256(abi.encodePacked(owner, block.timestamp)));
    }

    function pickWinner() public {
        require(msg.sender == owner);
        uint index = getRandomNumber() % players.length;
        players[index].transfer(address(this).balance);

        lotteryHistory[lotteryId] = players[index];
        lotteryId++;
        

        // reset the state of the contract
        delete players;
    }

    
}
