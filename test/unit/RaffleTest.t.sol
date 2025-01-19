// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {Constants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, Constants {
    //Error messages
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 interval;
    uint256 entranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;
    LinkToken link;

    // Player address and balances
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    // Setup function to deploy the Raffle contract and initialize variables
    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        // Fund the player with the starting balance
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        interval = config.interval;
        entranceFee = config.raffleEntranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        link = LinkToken(config.link);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subscriptionId, LINK_BALANCE);
        }
        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);
        vm.stopPrank();
    }

    //Creating modifiers for repteadly used functions
    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    //TESTS
    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWHenYouDontPayEnought() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayers(0);
        assert(playerRecorded == PLAYER);
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public raffleEnteredAndTimePassed {
        // Arrange
        // modifier used
        raffle.performUpkeep("");

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //CHECKUPKEEP Test
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public raffleEnteredAndTimePassed {
        // Arrange
        //modifier used
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == false);
    }

    function testCantEnterWhenRaffleIsCalculating() public raffleEnteredAndTimePassed {
        // Arrange
        //modifier used
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //PerformUpkeep Test
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public raffleEnteredAndTimePassed {
        // Arrange
        //modifier used

        // Act

        // Assert
        raffle.performUpkeep("");
    }

    // function testCheckUpkeepReturnsTrueWhenParametersGood() public {
    //     // Arrange
    //     vm.prank(PLAYER);
    //     raffle.enterRaffle{value: entranceFee}();
    //     vm.warp(block.timestamp + interval + 1);
    //     vm.roll(block.number + 1);

    //     // Act
    //     (bool upkeepNeeded, ) = raffle.checkUpkeep("");

    //     // Assert
    //     assert(upkeepNeeded);
    // }

    // function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
    //     // Arrange
    //     vm.prank(PLAYER);
    //     raffle.enterRaffle{value: entranceFee}();
    //     vm.warp(block.timestamp + interval + 1);
    //     vm.roll(block.number + 1);

    //     // Act / Assert
    //     // It doesnt revert
    //     raffle.performUpkeep("");
    // }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState)
        );
        raffle.performUpkeep("");
    }

    //test using the output of an event
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAndTimePassed {
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // 0 = open, 1 = calculating
    }

    //FULFILLRANDOMWORDS TEST
    // function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep()
    //     public
    //     raffleEnteredAndTimePassed
    //     skipFork
    // {
    //     // Arrange
    //     // Act / Assert
    //     vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
    //     // vm.mockCall could be used here...
    //     VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
    //         0,
    //         address(raffle)
    //     );

    //     vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
    //     VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(
    //         1,
    //         address(raffle)
    //     );
    // }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        //vm.expectRevert("nonexistent request");
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFullfillRandomWordsPicksAWinnerResetsAndSendSMoney() public raffleEnteredAndTimePassed skipFork {
        // Arrange
        //modifier used
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (uint256 i = startingIndex; i < additionalEntrants; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        //pretend to be chanlink vrf to get the random number and pick winner
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(uint256(requestId), address(raffle));

        //uint256 previousTimeStamp = raffle.getLastTimeStamp();

        //assert
        assert(uint256(raffle.getRaffleState()) == 0); // 0 = open, 1 = calculating
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);

        // assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(raffle.getRecentWinner().balance == prize + STARTING_USER_BALANCE - entranceFee * 2);
    }
}
