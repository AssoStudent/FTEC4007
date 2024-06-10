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
        uint winning_bonus;
    }
    singleBet[] private bets;

    // money pool
    uint256 private prize_pool;

    // contract settings
    uint private constant MAX_BETS_PER_PLAYER = 3; // Set upper limit of bets per player
    uint private constant WITHDRAWAL_PENALTY_PERCENT = 10; // Penalty for early withdrawal
    uint private constant MAX_PLAYERS_IN_GAME = 100; // Set upper limit of players in the game
    uint private constant PRIZE_POOL_RATIO = 1; // Set how much money are used as reward from the prize pool
    uint private constant WINNING_BONUS_RATIO = 1; // Set how much the multiplier in winning
    uint private constant GUESS_NUMBER_1_MIN = 1; // Set the GUESSNUMBER 1 range minimun 
    uint private constant GUESS_NUMBER_1_MAX = 1; // Set the GUESSNUMBER 1 range maximum
    uint private constant GUESS_NUMBER_2_MIN = 1; // Set the GUESSNUMBER 2 range minimun 
    uint private constant GUESS_NUMBER_2_MAX = 1; // Set the GUESSNUMBER 2 range maximum 
    uint private constant GUESS_NUMBER_3_MIN = 1; // Set the GUESSNUMBER 3 range minimun 
    uint private constant GUESS_NUMBER_3_MAX = 1; // Set the GUESSNUMBER 3 range maximum
    
    constructor() {
        owner = msg.sender;
    }

    // **************************************
    //  Query Functions
    // **************************************
    function getBalance() public view returns (uint) {
        return address(this).balance;
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

    function getBetDetails(uint256 id) public view returns (address payable, uint, uint, uint, uint, uint, bool) {
        require(id < bets.length, "Invalid bet ID");
        return (bets[id].player_address, bets[id].lotteryId, bets[id].betValue, bets[id].GuessNumber1, bets[id].GuessNumber2, bets[id].GuessNumber3, bets[id].discarded);
    }

    function enquiryValidGuessMinMax() public pure returns (uint, uint, uint, uint, uint, uint) {
        return (GUESS_NUMBER_1_MIN, GUESS_NUMBER_1_MAX, GUESS_NUMBER_2_MIN, GUESS_NUMBER_2_MAX, GUESS_NUMBER_3_MIN, GUESS_NUMBER_3_MAX);
    }

    // **************************************
    //  Player Functions
    // **************************************
    function enter(uint GuessNumber1, uint GuessNumber2, uint GuessNumber3) public payable {
        require(msg.value == 1 ether, "You must send exactly 1 ETH.");
        require(player_record.length < MAX_PLAYERS_IN_GAME, "Do not allow new players enter the game because it has reached the limitation already.");
        require(player[msg.sender].BetsCount < MAX_BETS_PER_PLAYER, "You has reached the maximum number of bets");
        require(GuessNumber1 >= GUESS_NUMBER_1_MIN && GuessNumber1 <= GUESS_NUMBER_1_MAX, "The guess number 1 should be in valid range.");
        require(GuessNumber2 >= GUESS_NUMBER_2_MIN && GuessNumber2 <= GUESS_NUMBER_2_MAX, "The guess number 2 should be in valid range.");
        require(GuessNumber3 >= GUESS_NUMBER_3_MIN && GuessNumber3 <= GUESS_NUMBER_3_MAX, "The guess number 3 should be in valid range.");
        uint256 id;
        id = bets.length;
        bets.push(singleBet(payable(msg.sender), id, msg.value, GuessNumber1, GuessNumber2, GuessNumber3, false, 0));
        player_record.push(payable(msg.sender));
        player[msg.sender].Balances += msg.value;
        player[msg.sender].BetsCount += 1;
        player[msg.sender].lotteryIdOwn.push(id);
    }

    function withdraw(uint256 id) public {
        require(id < bets.length, "Invalid bet ID");
        require(msg.sender == bets[id].player_address, "You are not the owner of this bet. Access denied.");
        require(player[msg.sender].Balances > 0, "You have no funds to withdraw");

        // Disable bet
        bets[id].discarded = true;

        // Bet value refund
        uint256 penalty = (bets[id].betValue * WITHDRAWAL_PENALTY_PERCENT) / 100;
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
            if (player[msg.sender].lotteryIdOwn[i] == id) {
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
    function getRandomNumber(uint range_min, uint range_max) private view returns (uint) {
        uint256 randomNumber = uint(keccak256(abi.encodePacked(owner, block.timestamp, player_record)));
        return uint((randomNumber % range_max) + range_min);
    }

    function fillMoneyToPool() public payable {
        require(msg.sender == owner, "Only the owner can fill the money to the prize pool.");
    }

    function getMoneyOutPool() public {
        require(msg.sender == owner, "Only the owner can get the money out from the prize pool.");
        require(player_record.length == 0, "Can only get the money out from the prize pool when no players has been in a game.");
        payable(msg.sender).transfer(address(this).balance);
    }


    function pickWinner() public {
        require(msg.sender == owner, "Only the owner can pick a winner");
        require(player_record.length > 0, "No players in the lottery");
        require(address(this).balance / PRIZE_POOL_RATIO > MAX_PLAYERS_IN_GAME * 3 * WINNING_BONUS_RATIO, "Not enough money to distribute players.");

        uint ResultNumber1 = getRandomNumber(GUESS_NUMBER_1_MIN, GUESS_NUMBER_1_MAX);
        uint ResultNumber2 = getRandomNumber(GUESS_NUMBER_2_MIN, GUESS_NUMBER_2_MAX);
        uint ResultNumber3 = getRandomNumber(GUESS_NUMBER_3_MIN, GUESS_NUMBER_3_MAX);
    
        // Check Matching
        uint bonus_ratio = 0;
        for (uint256 id = 0; id < bets.length; id++) {
            if (bets[id].discarded == false) {
                bonus_ratio = 0;
                if (bets[id].GuessNumber1 == ResultNumber1) {
                    bonus_ratio += WINNING_BONUS_RATIO;
                }
                if (bets[id].GuessNumber2 == ResultNumber2) {
                    bonus_ratio += WINNING_BONUS_RATIO;
                }
                if (bets[id].GuessNumber3 == ResultNumber3) {
                    bonus_ratio += WINNING_BONUS_RATIO;
                }
                bets[id].winning_bonus = bonus_ratio;
            }
        }

        // Distribute the prizes
        uint reward = (address(this).balance / PRIZE_POOL_RATIO) / bets.length;
        for (uint id = 0; id < bets.length; id++) {
            payable(bets[id].player_address).transfer(reward * bets[id].winning_bonus);
        }

        // Reset variables
        for (uint i = 0; i < player_record.length; i++) {
            player[player_record[i]].Balances = 0;
            player[player_record[i]].BetsCount = 0;
            delete player[player_record[i]].lotteryIdOwn;
        }
        delete player_record;
        delete bets;
    }

    // Additional function to reset the contract (can be called by the owner only)
    function resetLottery() public {
        require(msg.sender == owner, "Only the owner can reset the lottery");
        for (uint i = 0; i < player_record.length; i++) {
            payable(player_record[i]).transfer(player[player_record[i]].Balances);
            player[player_record[i]].Balances = 0;
            player[player_record[i]].BetsCount = 0;
            delete player[player_record[i]].lotteryIdOwn;
        }
        delete player_record;
        delete bets;
    }
}