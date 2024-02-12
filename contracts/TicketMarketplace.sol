// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ITicketNFT} from "./interfaces/ITicketNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TicketNFT} from "./TicketNFT.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol"; 
import {ITicketMarketplace} from "./interfaces/ITicketMarketplace.sol";
import "hardhat/console.sol";

contract TicketMarketplace is ITicketMarketplace{

    struct Event {
        uint128 nextTicketToSell;
        uint128 maxTickets;
        uint256 pricePerTicket;
        uint256 pricePerTicketERC20;
    }

    mapping(uint128 => Event) public events;
    uint128 public currentEventId;
    TicketNFT public nftContract;
    address public ERC20Address;
    address public immutable owner;


    constructor(address _ERC20Address) {
        owner = address(msg.sender);
        ERC20Address = _ERC20Address;
        nftContract = new TicketNFT();
        currentEventId = 0;
    }

    function createEvent(uint128 maxTickets, uint256 pricePerTicket, uint256 pricePerTicketERC20) external {
        require(msg.sender == owner, "Unauthorized access");
        events[currentEventId] = Event(0, maxTickets, pricePerTicket, pricePerTicketERC20);
        emit EventCreated(currentEventId, maxTickets, pricePerTicket, pricePerTicketERC20);
        currentEventId ++;
    }

    function setMaxTicketsForEvent(uint128 eventId, uint128 newMaxTickets) external {
        require(msg.sender == owner, "Unauthorized access");
        require(newMaxTickets >= events[eventId].maxTickets, "The new number of max tickets is too small!");
        events[eventId].maxTickets = newMaxTickets;
        emit MaxTicketsUpdate(eventId, newMaxTickets);
    }

    function setPriceForTicketETH(uint128 eventId, uint256 price) external {
        require(msg.sender == owner, "Unauthorized access");
        events[eventId].pricePerTicket = price;
        emit PriceUpdate(eventId, price, "ETH");
    }

    function setPriceForTicketERC20(uint128 eventId, uint256 price) external {
        require(msg.sender == owner, "Unauthorized access");
        events[eventId].pricePerTicketERC20 = price;
        emit PriceUpdate(eventId, price, "ERC20");
    }

    function buyTickets(uint128 eventId, uint128 ticketCount) payable external {
        // Check for overflow
        uint256 overflow_check_ticket_count = (2**256 - 1) / events[eventId].pricePerTicket; // Calculate total price
        require(overflow_check_ticket_count >= ticketCount, "Overflow happened while calculating the total price of tickets. Try buying smaller number of tickets.");

        // Check if ticket is enough
        require(events[eventId].maxTickets >= ticketCount, "We don't have that many tickets left to sell!");

        require(msg.value >= events[eventId].pricePerTicket * ticketCount, "Not enough funds supplied to buy the specified number of tickets.");
        for (uint128 i = 0; i < ticketCount; i++) {
            nftContract.mintFromMarketPlace(msg.sender, (eventId << 128) + events[eventId].nextTicketToSell + i);
        }
        events[eventId].nextTicketToSell += ticketCount;
        emit TicketsBought(eventId, ticketCount, "ETH");
    }

    function buyTicketsERC20(uint128 eventId, uint128 ticketCount) external {
        // Check for overflow
        uint256 overflow_check_ticket_count = (2**256 - 1) / events[eventId].pricePerTicketERC20; // Calculate total price
        require(overflow_check_ticket_count >= ticketCount, "Overflow happened while calculating the total price of tickets. Try buying smaller number of tickets.");

        // Check if ticket is enough
        require(events[eventId].maxTickets >= ticketCount, "We don't have that many tickets left to sell!");

        IERC20 token = IERC20(ERC20Address);
        token.transferFrom(msg.sender, address(this), events[eventId].pricePerTicketERC20 * ticketCount);
        for (uint128 i = 0; i < ticketCount; i++) {
            nftContract.mintFromMarketPlace(msg.sender, (eventId << 128) + events[eventId].nextTicketToSell + i);
        }
        events[eventId].nextTicketToSell += ticketCount;
        emit TicketsBought(eventId, ticketCount, "ERC20");
    }

    function setERC20Address(address newERC20Address) external {
        require(msg.sender == owner, "Unauthorized access");
        ERC20Address = newERC20Address;
        emit ERC20AddressUpdate(newERC20Address);
    }
}