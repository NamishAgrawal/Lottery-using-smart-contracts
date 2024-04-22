//SPDX-Liscense-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2{

    enum Raffle_State{
        OPEN,
        CLOSED
    }

    error Raffle_NotEnoughEth();
    error Raffle_NotEnoughTimeElapsed();
    error Raffle_TransferFailed();
    error Raffle_InvalidState();

    VRFCoordinatorV2Interface private immutable COORDINATOR;
    uint private ticketPrice;
    address payable[] private s_players;
    address[] private s_recentWinners;
    uint private timeInterval;
    uint private s_lastTimestamp;
    Raffle_State private s_RaffleState;
    bytes32 private immutable keyHash;
    uint64 private immutable s_subscriptionId;
    uint16 private immutable requestConfirmations =3;
    uint32 private immutable callbackGasLimit;
    uint32 private immutable numWords =1;
    //events
    event Raffle_Entered(address indexed _from);
    event Raffle_Winner(address indexed _winner);
    event WinnerPicked(address indexed _winner);
    event Raffle_Closed();



    constructor(uint _ticketPrice,uint _timeInterval, address _coordinator,bytes32 _keyHash,uint64 _subscriptionId,uint32 _callbackGasLimit) 
     VRFConsumerBaseV2(_coordinator){
        ticketPrice = _ticketPrice;
        s_RaffleState = Raffle_State.OPEN;
        s_subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;
        keyHash = _keyHash;
        COORDINATOR = VRFCoordinatorV2Interface(_coordinator);
        timeInterval = _timeInterval;
        s_lastTimestamp = block.timestamp;
       
    }

    function enterRaffle() payable public {
        if(msg.value <ticketPrice){
            revert Raffle_NotEnoughEth();
        }
        if(s_RaffleState != Raffle_State.OPEN){
            revert Raffle_InvalidState();
        }
        s_players.push(payable(msg.sender));
        emit Raffle_Entered(msg.sender);
    }

    function checkUpKeep(bytes memory /*checkData*/)public view returns (bool upKeepNeeded, bytes memory /*performData*/){
        
    }

    function pickWinner() public returns(address) {
        if((block.timestamp- s_lastTimestamp) < timeInterval){
            revert Raffle_NotEnoughTimeElapsed();
        }
            s_RaffleState = Raffle_State.CLOSED;
            uint requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    function fulfillRandomWords(uint256 _requestId,uint256[] memory _randomwords)internal override{
        uint indexOfWinner = _randomwords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinners.push(winner);
        (bool success,)= winner.call{value:address(this).balance}("");
        if(!success){
            revert Raffle_TransferFailed();
        }
        s_RaffleState = Raffle_State.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        emit WinnerPicked(winner);
    }
    //getters
    function getTicketPrice() public view returns(uint) {
        return ticketPrice;
    }
}