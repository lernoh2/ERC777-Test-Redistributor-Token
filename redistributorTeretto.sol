// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.1/contracts/token/ERC777/ERC777.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.1/contracts/utils/Strings.sol";

contract ETTO_Redistributor_1 is IERC777Recipient, ReentrancyGuard { 

    using Strings for uint256;
    using SafeMath for uint256;
    address public owner;
    uint256 public transfersCount;
    address public immutable ETTO;
    uint256 public cycleId;
    address private lastSender;
    uint256 private profit;
    address public presale;
    event Received(address from, address to, uint256 amount);
    event RandomNumber1(uint256 randomNumber);
    event RandomNumber2(uint256 randomNumber);
    event RandomNumber3(uint256 randomNumber);
    event TransfersCount(string transfersCount);
    event CycleId(uint256 cycleId);
    event Redistributed(address from, address to, uint256 profit);
    bool private presaleSet = false;

    constructor (address _etto) {
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24)
            .setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
        ETTO = _etto;
        cycleId = 1;
        owner = msg.sender;
    }

    function setPresale(address _presale) external onlyOwner {
        require(_presale != address(0), "Invalid address");
        require(msg.sender == owner, "Only owner can set the Presale address");
        require(!presaleSet, "Presale address has already been set.");
        presale = _presale;
        presaleSet = true;
    }

    function getRandomNumber1() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(transfersCount, owner, getRandomNumber5(), msg.sender, getRandomNumber4(), balanceOf(), block.timestamp,  blockhash(block.number-1), cycleId, address(this), lastSender, profit, getRandomNumber6()));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 100 + 2;
        return randomNumber;
    }

    function getRandomNumber2() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(profit, balanceOf(), owner, getRandomNumber5(), block.timestamp,  msg.sender, getRandomNumber6(), transfersCount,  blockhash(block.number-1), address(this), cycleId, lastSender, getRandomNumber4()));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 100 + 2;
        return randomNumber;
    }

    function getRandomNumber3() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(block.timestamp, cycleId, transfersCount, address(this), getRandomNumber5(), profit, lastSender, msg.sender, owner, getRandomNumber4(), balanceOf(), getRandomNumber6(), blockhash(block.number-1)));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 100 + 2;
        return randomNumber;
    }

    function getRandomNumber4() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(transfersCount, owner, msg.sender, balanceOf(), block.timestamp,  blockhash(block.number-1), cycleId, address(this), lastSender, profit));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 110 + 2;
        return randomNumber;
    }

    function getRandomNumber5() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(profit, balanceOf(), owner, block.timestamp,  msg.sender, transfersCount,  blockhash(block.number-1), address(this), cycleId, lastSender));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 120 + 2;
        return randomNumber;
    }

    function getRandomNumber6() private view returns (uint256) {
        bytes32 random = keccak256(abi.encodePacked(block.timestamp, cycleId, transfersCount, address(this), profit, lastSender, msg.sender, owner, balanceOf(),  blockhash(block.number-1)));
        bytes32 hash = keccak256(abi.encodePacked(random));
        uint256 randomNumber = uint256(hash) % 130 + 2;
        return randomNumber;
    }

    function tokensReceived(address operator, address from, address to, uint256 amount, bytes calldata userData, bytes calldata operatorData) external override nonReentrant {
        require(operatorData.length >= 0, "OperatorData cannot be empty");
        require(userData.length >= 0, "UserData cannot be empty");
        require(to != address(0), "to cannot be the null address");
        require(operator != address(0), "Operator cannot be the null address");
        require(from != owner, "Token owner can't take part in redistribution");
        
        emit Received(from, address(this), amount);
        transfersCount++;
        emit TransfersCount(transfersCount.toString()); 
        uint256 randomNumber1 = getRandomNumber1();
        emit RandomNumber1(randomNumber1);
        uint256 randomNumber2 = getRandomNumber2();
        emit RandomNumber2(randomNumber2);
        uint256 randomNumber3 = getRandomNumber3();
        emit RandomNumber3(randomNumber3);
        if(from != presale) {
         require(amount == 0.06 * 10 ** 18, "To take part in redistribution you must send exactly 1 ETTO");
        }
        if (randomNumber1 < transfersCount && randomNumber2 < transfersCount && randomNumber3 < transfersCount && from != presale) {
            
            lastSender = from;
            profit = balanceOf().mul(60) / 100;
            ERC777(ETTO).transfer(lastSender, profit);
            emit Redistributed(address(this), lastSender, profit);
            reset();
        }
    }

    function balanceOf() public view returns(uint256) {
        return IERC777(ETTO).balanceOf(address(this));
    }

    function reset() internal {
        transfersCount = 0;
        cycleId ++;
        emit CycleId(cycleId);
    }

        modifier onlyOwner()
    {
        require(msg.sender == owner);
    _;
    }
}