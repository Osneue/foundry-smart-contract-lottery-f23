// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

/**
 * @title Raffle
 * @author Leo
 * @notice This is a smaple raffle contract
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2, ConfirmedOwner, AutomationCompatibleInterface {
    error Raffle__NotEnoughETHSent();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 participantsLength, uint256 s_raffleState);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint32 private immutable i_callbackGasLimit;
    uint64 private immutable i_subscriptionId;
    uint256 private immutable i_entranceFee;
    // @dev interval in seconds between draws
    uint256 private immutable i_interval;
    bytes32 private immutable i_gasLane;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint256 private s_lastTimeStamp;
    address payable[] private s_participants;
    address payable s_winner;
    RaffleState private s_raffleState;

    event EnteredRaffle(address indexed participant);
    event PickedWinner(address indexed winner);
    event RequestedRandomness(uint256 indexed requestId);

    constructor(
        uint256 fee,
        uint256 interval,
        uint64 subscriptionId,
        address coordinator,
        bytes32 gasLane,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(coordinator) ConfirmedOwner(msg.sender) {
        i_entranceFee = fee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_subscriptionId = subscriptionId;
        i_vrfCoordinator = VRFCoordinatorV2Interface(coordinator);
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHSent();
        }
        s_participants.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(bytes memory /*checkData*/ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /*performData*/ )
    {
        bool timeHasPassed = block.timestamp - s_lastTimeStamp >= i_interval;
        bool hasParticipants = s_participants.length > 0;
        bool hasBalance = address(this).balance > 0;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        upkeepNeeded = timeHasPassed && hasParticipants && hasBalance && isOpen;
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /*performData*/ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_participants.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        );

        emit RequestedRandomness(requestId);
    }

    // Checks, Effects, Interactions
    function fulfillRandomWords(
        uint256,
        /*_requestId*/
        uint256[] memory _randomWords
    ) internal override {
        // Checks
        // require or if --> revert

        // Effects
        // pick a winner
        uint256 winnerIndex = _randomWords[0] % s_participants.length;
        address payable winner = s_participants[winnerIndex];
        s_winner = winner;
        s_raffleState = RaffleState.OPEN;
        s_participants = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);

        // Interactions
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter function *
     */

    function getRaffleFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getParticipants(uint256 _index) external view returns (address) {
        return s_participants[_index];
    }

    function getParticipantsNumber() external view returns (uint256) {
        return s_participants.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getWinner() external view returns (address) {
        return s_winner;
    }
}
