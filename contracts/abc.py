// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITicketNFT {
    function mintFromMarketPlace(address to, uint256 nftId) external;
}

contract TicketMarketplace is Ownable {
    struct Event {
        uint128 nextTicketToSell;
        uint128 maxTickets;
        uint256 pricePerTicket;
        uint256 pricePerTicketERC20;
    }

    mapping(uint128 => Event) public events;
    uint128 public currentEventId;
    address public nftContract;
    address public ERC20Address;

    event EventCreated(uint128 eventId, uint128 maxTickets, uint256 pricePerTicket, uint256 pricePerTicketERC20);
    event PriceUpdate(uint128 eventId, uint256 newPrice, string priceType);
    event MaxTicketsUpdate(uint128 eventId, uint128 newMaxTickets);
    event TicketsBought(uint128 eventId, uint128 numberOfTickets, string boughtWith);
    event ERC20AddressUpdate(address newERC20Address);

    constructor(address _nftContract, address _ERC20Address) {
        nftContract = _nftContract;
        ERC20Address = _ERC20Address;
    }

    function createEvent(uint128 maxTickets, uint256 pricePerTicket, uint256 pricePerTicketERC20) external onlyOwner {
        events[currentEventId] = Event(0, maxTickets, pricePerTicket, pricePerTicketERC20);
        emit EventCreated(currentEventId, maxTickets, pricePerTicket, pricePerTicketERC20);
        currentEventId++;
    }

    function setMaxTicketsForEvent(uint128 eventId, uint128 newMaxTickets) external onlyOwner {
        require(newMaxTickets >= events[eventId].maxTickets, "The new number of max tickets is too small!");
        events[eventId].maxTickets = newMaxTickets;
        emit MaxTicketsUpdate(eventId, newMaxTickets);
    }

    function setPriceForTicketETH(uint128 eventId, uint256 price) external onlyOwner {
        events[eventId].pricePerTicket = price;
        emit PriceUpdate(eventId, price, "ETH");
    }

    function setPriceForTicketERC20(uint128 eventId, uint256 price) external onlyOwner {
        events[eventId].pricePerTicketERC20 = price;
        emit PriceUpdate(eventId, price, "ERC20");
    }

    function buyTickets(uint128 eventId, uint128 ticketCount) payable external {
        require(eventId < currentEventId, "Event does not exist");
        require(events[eventId].nextTicketToSell + ticketCount <= events[eventId].maxTickets, "We don't have that many tickets left to sell!");
        require(msg.value >= events[eventId].pricePerTicket * ticketCount, "Not enough funds supplied to buy the specified number of tickets.");
        
        // Mint NFTs and transfer to the buyer
        ITicketNFT(nftContract).mintFromMarketPlace(msg.sender, eventId);

        // Update nextTicketToSell
        events[eventId].nextTicketToSell += ticketCount;

        emit TicketsBought(eventId, ticketCount, "ETH");
    }

    function buyTicketsERC20(uint128 eventId, uint128 ticketCount) external {
        require(eventId < currentEventId, "Event does not exist");
        require(events[eventId].nextTicketToSell + ticketCount <= events[eventId].maxTickets, "We don't have that many tickets left to sell!");
        require(IERC20(ERC20Address).transferFrom(msg.sender, address(this), events[eventId].pricePerTicketERC20 * ticketCount), "Failed to transfer ERC20 tokens");

        // Mint NFTs and transfer to the buyer
        ITicketNFT(nftContract).mintFromMarketPlace(msg.sender, eventId);

        // Update nextTicketToSell
        events[eventId].nextTicketToSell += ticketCount;

        emit TicketsBought(eventId, ticketCount, "ERC20");
    }

    function setERC20Address(address newERC20Address) external onlyOwner {
        ERC20Address = newERC20Address;
        emit ERC20AddressUpdate(newERC20Address);
    }
}
