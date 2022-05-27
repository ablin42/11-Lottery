// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LotteryToken} from "./Token.sol";

/// @title A very simple lottery contract
/// @author Matheus Pagani
/// @notice You can use this contract for running a very simple lottery
/// @dev This contract implements a weak randomness source
/// @custom:teaching This is a contract meant for teaching only
contract Lottery is Ownable {
    /// @notice Address of the token used as payment for the bets
    LotteryToken public paymentToken;
    /// @notice Amount of ETH charged per Token purchased
    /// @return `purchaseRatio` in wei
    uint256 public purchaseRatio;
    /// @notice Amount of tokens required for placing a bet that goes for the prize pool
    /// @return `betPrice` in wei
    uint256 public betPrice;
    /// @notice Amount of tokens required for placing a bet that goes for the owner pool
    /// @return `betFee` in wei
    uint256 public betFee;
    /// @notice Amount of tokens in the prize pool
    /// @return `prizePool` in wei
    uint256 public prizePool;
    /// @notice Amount of tokens in the owner pool
    /// @return `ownerPool` in wei
    uint256 public ownerPool;
    /// @notice Flag indicating if the lottery is open for bets
    /// @return `betsOpen` boolean
    bool public betsOpen;
    /// @notice Timestamp of the lottery next closing date
    /// @return `betsClosingTime` timestamp 
    uint256 public betsClosingTime;
    /// @notice Mapping of prize available for withdraw for each account
    /// @return `prize` won by `address`
    mapping(address => uint256) public prize;

    /// @dev List of bet slots
    address[] _slots;

    /// @notice Constructor function
    /// @param tokenName Name of the token used for payment
    /// @param tokenSymbol Symbol of the token used for payment
    /// @param _purchaseRatio Amount of ETH charged per Token purchased
    /// @param _betPrice Amount of tokens required for placing a bet that goes for the prize pool
    /// @param _betFee Amount of tokens required for placing a bet that goes for the owner pool
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 _purchaseRatio,
        uint256 _betPrice,
        uint256 _betFee
    ) {
        paymentToken = new LotteryToken(tokenName, tokenSymbol);
        purchaseRatio = _purchaseRatio;
        betPrice = _betPrice;
        betFee = _betFee;
    }

    /// @notice Passes when the lottery is at closed state
    modifier whenBetsClosed() {
        require(!betsOpen, "Lottery is open");
        _;
    }

    /// @notice Passes when the lottery is at open state and the current block timestamp is lower than the lottery closing date
    modifier whenBetsOpen() {
        require(
            betsOpen && block.timestamp < betsClosingTime,
            "Lottery is closed"
        );
        _;
    }

    /// @notice Open the lottery for receiving bets
    /// @param closingTime timestamp for the bets' closing time
    function openBets(uint256 closingTime) public onlyOwner whenBetsClosed {
        require(
            closingTime > block.timestamp,
            "Closing time must be in the future"
        );
        betsClosingTime = closingTime;
        betsOpen = true;
    }

    /// @notice Give tokens based on the amount of ETH sent, uses `msg.value` divided by `purchaseRatio`
    function purchaseTokens() public payable {
        paymentToken.mint(msg.sender, msg.value / purchaseRatio);
    }

    /// @notice Charge the bet price and create a new bet slot with the sender address
    function bet() public whenBetsOpen {
        paymentToken.transferFrom(msg.sender, address(this), betPrice + betFee);
        ownerPool += betFee;
        prizePool += betPrice;
        _slots.push(msg.sender);
    }

    /// @notice Call the bet function `times` times
    /// @param times number of bets that should be made by sender
    function betMany(uint256 times) public {
        require(times > 0);
        while (times > 0) {
            bet();
            times--;
        }
    }

    /// @notice Close the lottery and calculates the prize, if any
    /// @dev Anyone can call this function if the owner fails to do so
    function closeLottery() public {
        require(block.timestamp >= betsClosingTime, "Too soon to close");
        require(betsOpen, "Already closed");
        if (_slots.length > 0) {
            uint256 winnerIndex = getRandomNumber() % _slots.length;
            address winner = _slots[winnerIndex];
            prize[winner] += prizePool;
            prizePool = 0;
            delete (_slots);
        }
        betsOpen = false;
    }

    /// @notice Get a random number calculated from the block hash of last block
    /// @dev This number could be exploited by miners
    /// @return notQuiteRandomNumber pseudo random number
    function getRandomNumber()
        public
        view
        returns (uint256 notQuiteRandomNumber)
    {
        notQuiteRandomNumber = uint256(blockhash(block.number - 1));
    }

    /// @notice Withdraw from that accounts prize pool
    /// @param amount to be withdrawn by sender
    function prizeWithdraw(uint256 amount) public{
        require(amount <= prize[msg.sender], "Not enough prize");
        prize[msg.sender] -= amount;
        paymentToken.transfer(msg.sender, amount);
    }

    /// @notice Withdraw from the owner pool
    /// @param amount to be withdraw by owner
    function ownerWithdraw(uint256 amount) public onlyOwner {
        require(amount <= ownerPool, "Not enough fees collected");
        ownerPool -= amount;
        paymentToken.transfer(msg.sender, amount);
    }

    /// @notice Burn tokens and give the equivalent ETH back to user
    /// @param amount to be burnt by sender
    function returnTokens(uint256 amount) public {
        paymentToken.burnFrom(msg.sender, amount);
        payable(msg.sender).transfer(amount * purchaseRatio);
    }
}
