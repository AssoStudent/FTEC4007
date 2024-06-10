// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

contract Lottery {
    // **************************************
    //  Global Variables
    // **************************************
    // owner of the contract
    address public owner;

    // players
    struct player_status {
        uint256 Balances;
        uint BetsCount;
        uint[] lotteryIdOwn;
    }
    mapping(address => player_status) private player;
    address payable[] private player_record;

    // bets
    struct singleBet{
        address payable player_address;
        uint256 lotteryId;
        uint betValue;
        uint GuessNumber1;
        uint GuessNumber2;
        uint GuessNumber3;
        bool discarded;
        bool match_number1;
        bool match_number2;
        bool match_number3;
    }
    singleBet[] private bets;
    
    // Result

    // money pool
    uint private prize_pool;

    // contract settings
    uint private constant MAX_BETS_PER_PLAYER = 3; // Set upper limit of bets per player
    uint private constant WITHDRAWAL_PENALTY_PERCENT = 10; // Penalty for early withdrawal
    uint private constant MAX_PLAYERS_IN_GAME = 100;
    uint private PRIZE_POOL_NUMBER_1_RATIO = 2;
    uint private PRIZE_POOL_NUMBER_2_RATIO = 2;
    uint private PRIZE_POOL_NUMBER_3_RATIO = 2;
    
    constructor() {
        owner = msg.sender;
    }

    // **************************************
    //  Query Functions
    // **************************************
    function getBalance() public view returns (uint) {
        return address(this).balances;
    }

    function getPlayerBalance() public view returns (uint) {
        return player[msg.sender].Balances;
    }

    function getPlayerAddresses() public view returns (address payable[] memory) {
        return player_record;
    }

    function getNumberOfPlayers() public view returns (uint) {
        return player_record.length;
    }

    function getNumberOfBets() public view returns (uint) {
        return bets.length;
    }

    function getNumberOfValidBets() public view returns (uint) {
        uint number = 0;
        for (uint ID = 0; ID < bets.length; ID++) {
            if (bets[ID].discarded == false) {
                number++;
            }
        }
        return number;
    }

    function getBetDetails(uint id) public view returns (address payable memory, uint, uint, uint, uint, uint, bool) {
        return (bets[id].player_address, bets[id].lotteryId, bets[id].betValue, bets[id].GuessNumber1, bets[id].GuessNumber2, bets[id].GuessNumber3, bets[id].discarded);
    }

    // **************************************
    //  Player Functions
    // **************************************
    function enter(uint GuessNumber1, uint GuessNumber2, uint GuessNumber3) public payable {
        require(msg.value == 1 ether, "You must send exactly 1 ETH.");
        require(player_record.length < MAX_PLAYERS_IN_GAME, "Do not allow new players enter the game because it has reached the limitation already.");
        require(player[msg.sender].playerBetsCount < MAX_BETS_PER_PLAYER, "You has reached the maximum number of bets");
        require(GuessNumber1 >= 1, "The guess number should be inbetween 1 and 10.");
        require(GuessNumber1 <= 10, "The guess number should be inbetween 1 and 10.");
        require(GuessNumber2 >= 1, "The guess number should be inbetween 1 and 10.");
        require(GuessNumber2 <= 10, "The guess number should be inbetween 1 and 10.");
        require(GuessNumber3 >= 1, "The guess number should be inbetween 1 and 10.");
        require(GuessNumber3 <= 10, "The guess number should be inbetween 1 and 10.");
        uint256 ID;
        ID = bets.length;
        bets.push(singleBet(payable(msg.sender), ID, msg.value, GuessNumber1, GuessNumber2, GuessNumber3, false, false, false, false));
        player_record.push(payable(msg.sender));
        player[msg.sender].Balances += msg.value;
        player[msg.sender].BetsCount += 1;
        player[msg.sender].lotteryIdOwn.push(ID);
    }

    function withdraw(uint256 ID) public {
        require(ID < bets.length, "Invalid bet ID");
        require(msg.sender == bets[ID].player_address, "You are not the owner of this bet. Access denied.");
        require(player[msg.sender].Balances > 0, "You have no funds to withdraw");

        // Disable bet
        bets[ID].discarded = true;

        // Bet value refund
        uint256 penalty = (bets[ID].betValue * WITHDRAWAL_PENALTY_PERCENT) / 100;
        uint256 withdrawalAmount = player[msg.sender].Balances - penalty;
        if (withdrawalAmount < 0) {
            withdrawalAmount = 0; // Avoid invalid withdraw amount for the player
        }

        player[msg.sender].Balances -= withdrawalAmount;
        payable(msg.sender).transfer(withdrawalAmount);

        // Recalculate the bet count for the player
        player[msg.sender].BetsCount -= 1;
        if (player[msg.sender].BetsCount < 0) {
            player[msg.sender].BetsCount = 0;  // Avoid invalid bet count for the player
        }

        // Remove the ID record in the player status
        for (uint256 i = 0; i < player[msg.sender].lotteryIdOwn.length; i++) {
            if (player[msg.sender].lotteryIdOwn[i] == ID) {
                player[msg.sender].lotteryIdOwn[i] = player[msg.sender].lotteryIdOwn[player[msg.sender].lotteryIdOwn.length - 1];
                player[msg.sender].lotteryIdOwn.pop();
                break;
            }
        }

        // Remove player from the player record if the player contains no any bets
        if (player[msg.sender].BetsCount == 0) {
            for (uint256 i = 0; i < player_record.length; i++) {
                if (player_record[i] == msg.sender) {
                    player_record[i] = player_record[player_record.length - 1];
                    player_record.pop();
                    break;
                }
            }
        }
    }

    // **************************************
    //  Owner Functions
    // **************************************
    function getRandomNumber() private view returns (uint) {
        uint256 randomNumber = uint(keccak256(abi.encodePacked(owner, block.timestamp, player_record)));
        return uint((randomNumber % 10) + 1);
    }

    function fillMoneyToPool() public payable {
        require(msg.sender == owner, "Only the owner can fill the money to the prize pool.");
    }

    function getMoneyOutPool() public {
        require(msg.sender == owner, "Only the owner can get the money out from the prize pool.");
        require(player_record.length == 0, "Can only get the money out from the prize pool when no players has been in a game.");
        owner.transfer(address(this).balance);
    }

    function setPrizeRatioNumber1()

    function pickWinner() public {
        //require(msg.sender == owner, "Only the owner can pick a winner");
        //require(player_record.length > 0, "No players in the lottery");

        uint ResultNumber1 = getRandomNumber();
        uint ResultNumber2 = getRandomNumber();
        uint ResultNumber3 = getRandomNumber();
    
        // Check Matching
        uint[] winners_bonus;
        uint bonus_ratio = 1;
        for (uint ID = 0; ID < bets.length; ID++) {
            if (bets[ID].discarded == false) {
                bonus_ratio = 1;
                if (bets[ID].GuessNumber1 == ResultNumber1) {
                    bets[ID].match_number1 == true;
                    bonus_ratio += 1;
                }
                if (bets[ID].GuessNumber2 == ResultNumber2) {
                    bets[ID].match_number2 == true;
                    winner_number2.push(bets[ID].player_address);
                    bonus_ratio += 1;
                }
                if (bets[ID].GuessNumber3 == ResultNumber3) {
                    bets[ID].match_number3 == true;
                    winner_number3.push(bets[ID].player_address);
                    bonus_ratio += 1;
                }
                winner_bonus.push(bonus_ratio);
            }
        }

        // Distribute the prizes
        for (uint256 i = 0; i < winner_number1.length; i++) {
            winner_number1.length(address(this).balance)
        }
        for (uint256 i = 0; i < winner_number2.length; i++) {
            winner_number2.length(address(this).balance)
        }
        for (uint256 i = 0; i < winner_number3.length; i++) {
            winner_number3.length(address(this).balance)
        }
    }

    // Additional function to reset the contract (can be called by the owner only)
    function resetLottery() external {
        require(msg.sender == owner, "Only the owner can reset the lottery");
        for (uint i = 0; i < player_record.length; i++) {
            player[player_record[i]].Balances = 0;
            player[player_record[i]].BetsCount = 0;
            delete player[player_record[i]].lotteryIdOwn;
        }
        delete player_record;
        delete bets;
    }
}