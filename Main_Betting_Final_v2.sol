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
        uint256 Balances; // to see how much a player has paid in the current round of betting
        uint BetsCount; // to count the number of bet that the player bets
        uint[] lotteryIdOwn; // to store the corresponding bet IDs that player own
    }
    mapping(address => player_status) private player; // player[address].Balance, player[address].BetsCount, player[address].lotteryIdown
    address payable[] private player_record; // store the player address for the current round of betting

    // bets
    struct singleBet{
        address payable player_address; // To store who own this bet
        uint256 lotteryId; // to identify the bet, unique for each round of betting
        uint betValue; // to show how much has been paid for buying this bet
        uint GuessNumber1;
        uint GuessNumber2;
        uint GuessNumber3;
        bool discarded; // to check whether this bet has been discard by the user
        uint winning_bonus; // for the use of PickWinner function distributing the prize
    }
    singleBet[] private bets; // bets[0], bets[1], ... bets[id]

    // results
    uint[] ResultNumber1_record;
    uint[] ResultNumber2_record;
    uint[] ResultNumber3_record;
    uint private currentResultNumber1_seed = uint(keccak256(abi.encodePacked(owner, block.timestamp, block.timestamp)));
    uint private currentResultNumber2_seed = uint(keccak256(abi.encodePacked(owner, block.timestamp, block.number)));
    uint private currentResultNumber3_seed = uint(keccak256(abi.encodePacked(owner, block.number, block.number)));
    bool private end = false;

    // contract settings
    uint private constant MAX_BETS_PER_PLAYER = 3; // Set upper limit of bets per player
    uint private constant WITHDRAWAL_PENALTY_PERCENT = 10; // Penalty for early withdrawal
    uint private constant MAX_PLAYERS_IN_GAME = 100; // Set upper limit of players in the game
    uint private constant PRIZE_POOL_RATIO = 1; // Set how much money are used as reward from the prize pool
    uint private constant WINNING_BONUS_RATIO = 1; // Set how much the multiplier in winning
    uint private constant GUESS_NUMBER_1_MIN = 1; // Set the GUESSNUMBER 1 range minimun 
    uint private constant GUESS_NUMBER_1_MAX = 3; // Set the GUESSNUMBER 1 range maximum
    uint private constant GUESS_NUMBER_2_MIN = 1; // Set the GUESSNUMBER 2 range minimun 
    uint private constant GUESS_NUMBER_2_MAX = 3; // Set the GUESSNUMBER 2 range maximum 
    uint private constant GUESS_NUMBER_3_MIN = 1; // Set the GUESSNUMBER 3 range minimun 
    uint private constant GUESS_NUMBER_3_MAX = 3; // Set the GUESSNUMBER 3 range maximum
    
    constructor() {
        owner = msg.sender;
    }

    // **************************************
    //  Query Functions
    // **************************************
    // To see how much has been put in this contract
    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    // To see how much the user has been put for the current round of betting
    function getPlayerBalance() public view returns (uint) {
        return player[msg.sender].Balances;
    }

    // To see a list of players that has entered the game
    function getPlayerAddresses() public view returns (address payable[] memory) {
        return player_record;
    }

    // For the user to see which ID the user owns
    function getPlayerLotteryIdOwn() public view returns (uint[] memory) {
        return player[msg.sender].lotteryIdOwn;
    }

    // To see how many player has entered the game, return total number instead of addresses
    function getNumberOfPlayers() public view returns (uint) {
        return player_record.length;
    }

    // To see how many bets has been made in the current round of betting
    function getNumberOfBets() public view returns (uint) {
        return bets.length;
    }

    // To see how many bet that has not discarded has been made in the current round of betting
    function getNumberOfValidBets() public view returns (uint) {
        uint number = 0;
        for (uint ID = 0; ID < bets.length; ID++) {
            if (bets[ID].discarded == false) {
                number++;
            }
        }
        return number;
    }

    // To see the guess number for a bet with requested id
    function getBetDetails(uint256 id) public view returns (address payable, uint, uint, uint, uint, uint, bool) {
        require(id < bets.length, "Invalid bet ID");
        return (bets[id].player_address, bets[id].lotteryId, bets[id].betValue, bets[id].GuessNumber1, bets[id].GuessNumber2, bets[id].GuessNumber3, bets[id].discarded);
    }

    // For users to check what are the valid values they should put in the GuessNumber
    function enquiryValidGuessMinMax() public pure returns (uint, uint, uint, uint, uint, uint) {
        return (GUESS_NUMBER_1_MIN, GUESS_NUMBER_1_MAX, GUESS_NUMBER_2_MIN, GUESS_NUMBER_2_MAX, GUESS_NUMBER_3_MIN, GUESS_NUMBER_3_MAX);
    }

    // For users to check the result history
    function checkResultHistory() public view returns (uint[] memory, uint[] memory, uint[] memory) {
        return (ResultNumber1_record, ResultNumber2_record, ResultNumber3_record);
    }

    // **************************************
    //  Player Functions
    // **************************************
    // enter the game
    function enter(uint GuessNumber1, uint GuessNumber2, uint GuessNumber3) public payable {
        require(msg.value == 1 ether, "You must send exactly 1 ETH.");
        require(player_record.length < MAX_PLAYERS_IN_GAME, "Do not allow new players enter the game because it has reached the limitation already.");
        require(player[msg.sender].BetsCount < MAX_BETS_PER_PLAYER, "You has reached the maximum number of bets");
        require(GuessNumber1 >= GUESS_NUMBER_1_MIN && GuessNumber1 <= GUESS_NUMBER_1_MAX, "The guess number 1 should be in valid range.");
        require(GuessNumber2 >= GUESS_NUMBER_2_MIN && GuessNumber2 <= GUESS_NUMBER_2_MAX, "The guess number 2 should be in valid range.");
        require(GuessNumber3 >= GUESS_NUMBER_3_MIN && GuessNumber3 <= GUESS_NUMBER_3_MAX, "The guess number 3 should be in valid range.");
        require(end == false, "Please wait until next round.");
        uint256 id;
        id = bets.length;
        bets.push(singleBet(payable(msg.sender), id, msg.value, GuessNumber1, GuessNumber2, GuessNumber3, false, 0));
        player_record.push(payable(msg.sender));
        player[msg.sender].Balances += msg.value;
        player[msg.sender].BetsCount += 1;
        player[msg.sender].lotteryIdOwn.push(id);
    }

    // withdraw a bet with request id
    function withdraw(uint256 id) public {
        require(id < bets.length, "Invalid bet ID");
        require(end == false, "The result has been released. Access denied.");
        require(msg.sender == bets[id].player_address, "You are not the owner of this bet. Access denied.");
        require(player[msg.sender].Balances > 0, "You have no funds to withdraw.");

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
    // return a random number in the range between range_min and range_max
    function getRandomNumber(uint range_min, uint range_max) private view returns (uint) {
        uint256 randomNumber = uint(keccak256(abi.encodePacked(owner, block.timestamp, player_record, currentResultNumber1_seed, currentResultNumber2_seed, currentResultNumber3_seed)));
        return uint((randomNumber % range_max) + range_min);
    }

    // for owner to increase the amount of the contract balance (can be called by the owner only)
    function fillMoneyToPool() public payable {
        require(msg.sender == owner, "Only the owner can fill the money to the prize pool.");
        require(msg.value > 0 ether && msg.value <= 100 ether, "The input value must be between 0 and 100.");
    }

    // for owner to get the money out from the contract (can be called by the owner only)
    function getMoneyOutPool() public {
        require(msg.sender == owner, "Only the owner can get the money out from the prize pool.");
        require(player_record.length == 0, "Can only get the money out from the prize pool when no players has been in the game.");
        payable(msg.sender).transfer(address(this).balance);
    }

    // draw 3 random numbers and then distribute the prize to those bets matching with the guess number
    // owner may has a privilege to start on any time (can be called by the owner only)
    function pickWinner() public returns (uint, uint, uint) {
        require(msg.sender == owner, "Only the owner can pick a winner");
        require(end == false, "The winner has been picked already. Please reset.");
        require(player_record.length > 0, "No players in the lottery");
        require(address(this).balance / PRIZE_POOL_RATIO >= MAX_PLAYERS_IN_GAME * MAX_BETS_PER_PLAYER * WINNING_BONUS_RATIO * 3, "Not enough money to distribute players.");
        // The prize pool for rewarding has to be larger than the maximum possible number of players multiply with maximum number of bets, and maximum number of winning bonus ratio.
        end = true;

        uint ResultNumber1 = getRandomNumber(GUESS_NUMBER_1_MIN, GUESS_NUMBER_1_MAX);
        currentResultNumber1_seed += ResultNumber1;
        uint ResultNumber2 = getRandomNumber(GUESS_NUMBER_2_MIN, GUESS_NUMBER_2_MAX);
        currentResultNumber2_seed += ResultNumber2 * ResultNumber1;
        uint ResultNumber3 = getRandomNumber(GUESS_NUMBER_3_MIN, GUESS_NUMBER_3_MAX);
        currentResultNumber3_seed += ResultNumber3 * ResultNumber2 * ResultNumber1;
    
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
        uint256 reward = ((address(this).balance / PRIZE_POOL_RATIO) / (WINNING_BONUS_RATIO * 3)) / bets.length;
        for (uint id = 0; id < bets.length; id++) {
            if (bets[id].discarded == false) {
                uint256 reward_each = reward * bets[id].winning_bonus;
                address payable winner = bets[id].player_address;
                if (reward_each > address(this).balance) {
                    address(this).balance;
                }
                if (reward_each > 0) {
                    winner.transfer(reward_each);
                }
            }
        }

        ResultNumber1_record.push(ResultNumber1);
        ResultNumber2_record.push(ResultNumber2);
        ResultNumber3_record.push(ResultNumber3);
        return (ResultNumber1, ResultNumber2, ResultNumber3);
    }

    // Additional function to reset the contract (can be called by the owner only)
    function resetLottery() public {
        require(msg.sender == owner, "Only the owner can reset the lottery");
        uint256 refund = 0;
        for (uint i = 0; i < player_record.length; i++) {
            refund = player[player_record[i]].Balances;
            player[player_record[i]].Balances = 0;
            player[player_record[i]].BetsCount = 0;
            delete player[player_record[i]].lotteryIdOwn;
            payable(player_record[i]).transfer(refund);
        }
        end = false;
        delete player_record;
        delete bets;
    }
}