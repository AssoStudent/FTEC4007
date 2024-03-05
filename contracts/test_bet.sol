pragma solidity 0.8.24;

contract bet {

    //event is for storing something on the blockchain to store every transaction
    //include necessary transaction information of better address, amount bet and for which team
    event NewBet(
        address addy,
        uint amount,
        Team teamBet
    );
    //object for each bet placed
    struct Bet {
        string name;
        address addy; //user address
        uint amount; //amount bet
        Team teamBet;
    }
    //object for each team(block number) up for betting
    struct Team {
        string name;
        uint totalBetAmount; //to update every bet placed
    }

    //array to store bets made and the teams to be bet on
    Bet[] public bets;
    Team[] public teams;

    //whem people place bet, ethereum is given to the contract owner
    //when bets are settled, ethereum is taken from the contract owner
    address payable conOwner; 
    //store total bet from both team combined
    //used for debugging
    uint public totalBetMoney = 0;

    //made such that each user can only bet once, if the uint == 0, else cannot place bet
    mapping (address => uint) public numBetsAddress;

    constructor() payable {
        //msg.sender is the one who call the function
        //the user calling constructor() owns the contract
        conOwner = payable(msg.sender);
        //create teams by pushing a "Team" object into the "teams" array
        //need to create a way such that user can create the team whenever they put a bet on a new block number
        teams.push(Team("team1", 0));
        teams.push(Team("team2", 0));
    }

    //teams have their own ID, "team1" ID is 0, "team2" ID is 1
    //I guess its the same as their position in the "teams" array
    function getTotalBetAmount (uint _teamID) public view returns (uint) {
        return teams[_teamID].totalBetAmount;
    }

    //called when user place a bet
    function createBet (string memory _name, uint _teamID) external payable {
        //check requirements for placing a valid bet
        require (msg.sender != conOwner, "owner cannot make a bet");
        require (numBetsAddress[msg.sender] == 0, "you have already placed a bet");
        require (msg.value > 0.01 ether, "place more ethereum for your bet");

        //put the bet information in the "bets" array as a "Bet" object
        bets.push(Bet(_name, msg.sender, msg.value, teams[_teamID]));

        //check which team to add the bet amount into
        if (_teamID == 0) {
            teams[0].totalBetAmount += msg.value;
        }
        if (_teamID == 1) {
            teams[1].totalBetAmount += msg.value;
        }

        //change the number of bets made by the user to be 1
        //so the same user cannot place another bet
        numBetsAddress[msg.sender]++;

        //caller placing bet give ethereum to owner of the contract/bet
        (bool sent, bytes memory data) = conOwner.call{value:msg.value}("");
        require(sent, "Failed to send Ether");

        //update total bet pool
        totalBetMoney += msg.value;

        //emit keyword is to call an event (put things on the blockchain)
        emit NewBet(msg.sender, msg.value, teams[_teamID]);
    }


    //don't know how to make this function only callable by the owner of the contract/bet
    //for block number, we can have this called whenever the bet closes in a predetermined time
    //maybe make it internal such that no one other than the contract can call it automatically?
    function teamWinDistribution(uint _teamID) public payable {
        
        //store total amount for each winner
        uint div;

        //calculate payment for each winner
        //need to think of a way to process winnings for each block number betted for
        if (block.number == 0) {
            for (uint i = 0; i < bets.length; i++) {
                //check if the user betted on the correct team
                if (keccak256(abi.encodePacked((bets[i].teamBet.name))) == keccak256(abi.encodePacked("team1"))) {
                    address payable receiver = payable(bets[i].addy);
                    //console.log(receiver);
                    //compute amount to pay the user
                    div = (bets[i].amount * (10000 + (getTotalBetAmount(1) * 10000 / getTotalBetAmount(0)))) / 10000;

                    //send the winnings to the user
                    (bool sent, bytes memory data) = receiver.call{ value: div }("");
                    require(sent, "Failed to send Ether to winner");
                }
            }
        }

        //reset values for the next bet creation
        totalBetMoney = 0;
        teams[0].totalBetAmount = 0;
        teams[0].totalBetAmount = 0;

        for (uint i = 0; i < bets.length; i++) {
            numBetsAddress[bets[i].addy] = 0;
        }
    }
}