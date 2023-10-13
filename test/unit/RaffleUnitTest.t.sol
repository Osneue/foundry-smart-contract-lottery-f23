// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleUnitTest is Test {
    Raffle raffle;
    address player = makeAddr("player");
    uint256 constant INITIAL_BALANCE = 1 ether;
    uint256 entranceFee;
    uint256 interval;
    uint64 subscriptionId;
    address coordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;

    event EnteredRaffle(address indexed participant);
    event PickedWinner(address indexed winner);

    modifier updateTimeStampAndAddPlayer() {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        _;
    }

    modifier addAdditionalPlayers() {
        uint256 startingIndex = 1;
        uint256 additionalPlayerNum = 5;

        for (uint256 i = startingIndex; i < startingIndex + additionalPlayerNum; i++) {
            address additionalPlayer = address(uint160(i));
            hoax(additionalPlayer, INITIAL_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        _;
    }

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        HelperConfig helperConfig;
        HelperConfig.NetworkConfig memory networkConfig;

        (raffle, helperConfig) = deployRaffle.run();
        networkConfig = helperConfig.getNetworkConfig();
        entranceFee = networkConfig.fee;
        interval = networkConfig.interval;
        coordinator = networkConfig.coordinator;

        vm.deal(player, INITIAL_BALANCE);
    }

    function test_IfInitialStateOfRaffleIsOpen() external {
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
    }

    /**
     * Tests for enterRaffle()
     */

    function test_CannotEnterRaffleWithoutEngouthETH() external {
        vm.prank(player);
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSent.selector);
        raffle.enterRaffle();
    }

    function test_SinglePlayerEnterRaffleCanUpdateParticipants() external {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.getParticipants(0), player);
    }

    function test_EventCanEmitWhenPlayerEnterRaffle() external {
        vm.prank(player);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(player);
        raffle.enterRaffle{value: entranceFee}();
    }

    function test_CannotEnterRaffleWhenStateIsNotOpen() external updateTimeStampAndAddPlayer {
        vm.prank(msg.sender);
        raffle.performUpkeep("");
        vm.prank(player);
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /**
     * Tests for checkUpkeep()
     */

    function test_checkUpKeepReturnsFalseIfNoBalanceOrParticipant() external {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function test_checkUpKeepReturnsFalseIfRaffleNotOpen() external updateTimeStampAndAddPlayer {
        vm.prank(msg.sender);
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function test_checkUpKeepReturnsFalseIfTimeHaventPassed() external {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function test_checkUpKeepReturnsTrueIfAllParametersAreGood() external updateTimeStampAndAddPlayer {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    /**
     * Tests for performUpkeep()
     */

    function test_performUpkeepCanRunIfCheckUpKeepReturnsTrue() external updateTimeStampAndAddPlayer {
        vm.prank(msg.sender);
        raffle.performUpkeep("");
    }

    function test_performUpkeepRevertsIfCheckUpKeepReturnsFalse() external {
        uint256 balance = 0;
        uint256 players = 0;
        uint256 state = uint256(Raffle.RaffleState.OPEN);
        vm.prank(msg.sender);
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, balance, players, state));
        raffle.performUpkeep("");
    }

    function test_performUpkeepCanUpdateStateAndLog() external updateTimeStampAndAddPlayer {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState state = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(state == Raffle.RaffleState.CALCULATING);
    }

    modifier skipFork() {
        uint256 ANVIL_CHAIN_ID = 31337;
        if (block.chainid != ANVIL_CHAIN_ID) {
            return;
        }
        _;
    }

    /**
     * Tests for fulfillRandomWords()
     */

    function test_fulfillRandomWordsRevertsIfCalledBeforePerformUpkeep(uint256 requestId) external skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(requestId, address(raffle));
    }

    function test_fulfillRandomWordsCanUpdateTimeStamp()
        external
        updateTimeStampAndAddPlayer
        addAdditionalPlayers
        skipFork
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        uint256 beforeTimeStamp = raffle.getLastTimeStamp();

        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        uint256 afterTimeStamp = raffle.getLastTimeStamp();
        assert(afterTimeStamp > beforeTimeStamp);
    }

    function test_fulfillRandomWordsCanUpdateState()
        external
        updateTimeStampAndAddPlayer
        addAdditionalPlayers
        skipFork
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        Raffle.RaffleState afterState = raffle.getRaffleState();
        assert(afterState == Raffle.RaffleState.OPEN);
    }

    function test_fulfillRandomWordsCanClearParticipants()
        external
        updateTimeStampAndAddPlayer
        addAdditionalPlayers
        skipFork
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        assert(raffle.getParticipantsNumber() == 0);
    }

    function test_fulfillRandomWordsCanPickWinner()
        external
        updateTimeStampAndAddPlayer
        addAdditionalPlayers
        skipFork
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        assert(raffle.getWinner() != address(0));
    }

    function test_fulfillRandomWordsCanSendPickedWinnerEvent()
        external
        updateTimeStampAndAddPlayer
        addAdditionalPlayers
        skipFork
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        vm.recordLogs();
        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        entries = vm.getRecordedLogs();
        bytes32 winner = entries[0].topics[1];

        assert(address(uint160(uint256(winner))) == raffle.getWinner());
    }

    function test_fulfillRandomWordsCanPayWinner() external updateTimeStampAndAddPlayer addAdditionalPlayers skipFork {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 playerBalance = player.balance; // each participant has the same balance, so we can use player as an example
        uint256 price = address(raffle).balance;

        vm.recordLogs();
        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        address winner = raffle.getWinner();
        assert(winner.balance == playerBalance + price);
        assert(address(raffle).balance == 0);
    }
}
