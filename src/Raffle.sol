//1. get a random number
//2. Use the random number to pick a winner
//3. Be automatically called by Chainlink VRF

// SPDX-a short identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console} from "forge-std/console.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    //Gas efficient way to create custom errors, instead of using require
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    //**Type declarations */
    //Set the state of the raffle
    enum RaffleState {
        OPEN, //0s
        CALCULATING //1
        // CLOSED //2
    }

    //**State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    //setting the entrance fee as immutable, so it can't be changed.
    uint256 public immutable i_entranceFee;
    //duration of the loteery in seconds
    uint256 public immutable i_interval;
    //uint256 private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint256 public immutable i_subscriptionId;
    uint32 public immutable i_callbackGasLimit;
    //sotre the players in an array, and pay the winner, so it is payable

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /**
     * Event
     */
    event EnterRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    //initialise the state variables
    // constructor(
    //     uint256 entranceFee,
    //     uint256 interval,
    //     address vrfCoordinator,
    //     bytes32 gasLane,
    //     uint64 subscriptionId,
    //     uint32 callbackGaLimit
    // ) {
    //     i_entranceFee = entranceFee;
    //     i_interval = interval;
    //     s_lastTimeStamp = block.timestamp;
    //     i_vrfCoordinator = VRFConsumerBaseV2Plus(vrfCoordinator);
    //     i_gasLane = gasLane;
    //     i_subscriptionId = subscriptionId;
    //     i_callbackGasLimit = callbackGaLimit;
    // }
    constructor(
        uint256 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        // uint256 balance = address(this).balance;
        // if (balance > 0) {
        //     payable(msg.sender).transfer(balance);
        // }
    }

    //using external to save gas, we proboably don't need to call this function from within the contract.
    function enterRaffle() public payable {
        //require(msg.value >= i_entranceFee, "Not enough ETH sent");
        //Same function as above, but gas effcient way, use revert functions, this is the best way to use.
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        //add the player to the array
        //You can only enter the raffle if it is open
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnterRaffle(msg.sender);
    }

    //Chainlink automation setup
    /**
     * @dev This is the function that Chainlink Automation nodes call
     * to see if it is time to perform an upkeep task.
     * The folowiing should be true for this return true:
     * 1. The time interval has passed between raffle runs
     * 2. The raffle is in the OPEN state
     * 3. The contract has ETH (aka, layers)
     * 4. (Implicit) The subscription is funded with LINK
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // can we comment this out?
    }

    /**
     * @dev Once `checkUpkeep` is returning `true`, this function is called
     * and it kicks off a Chainlink VRF call to get a random winner.
     */
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        // require(upkeepNeeded, "Upkeep not needed");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        //check to see if enought time has passed
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        emit RequestedRaffleWinner(requestId);
    }

    //CEI: Check-Effect-Interaction
    function fulfillRandomWords(
        uint256,
        /**
         * requestId
         */
        uint256[] calldata randomWords
    ) internal override {
        //Checks
        //Effects(Our Own Contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;

        //Set the  state back to open
        s_raffleState = RaffleState.OPEN;

        //reset t he players array
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        //Interaction(other contracts)
        //winner.transfer(address(this).balance);
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }

        //Sice we picked a winner and updated the state, we can emit an event
        emit WinnerPicked(winner);
    }

    function getEntrancefee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
