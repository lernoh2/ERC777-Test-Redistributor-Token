// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.1/contracts/token/ERC777/ERC777.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";


    contract ETTO_Presale is IERC777Recipient, ReentrancyGuard {

    using SafeMath for uint256;
    address public owner;
    ERC777 private ETTO;
    address payable immutable lp;
    uint256 public immutable rate;
    uint256 public maticRaised;
    mapping(address => bool) public hasPurchased;
    event Received(address from, address to, uint256 amount);
    event Purchased(address indexed beneficiary, uint256 maticAmount, uint256 tokenAmount);
    event LiquidityAdded(address from, address to, uint256 maticAmount, uint256 maticRaised);

    constructor (uint256 _rate, address payable _lp, ERC777 _etto) {
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24)
            .setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
        rate = _rate;
        lp = payable(_lp);
        ETTO = _etto;
        owner = msg.sender;
    }


    function tokensReceived(address operator, address from, address to, uint256 amount, bytes calldata userData, bytes calldata operatorData) external override nonReentrant {
        require(operatorData.length >= 0, "OperatorData cannot be empty");
        require(userData.length >= 0, "UserData cannot be empty");
        require(to != address(0), "to cannot be the null address");
        require(operator != address(0), "Operator cannot be the null address");
        require(from == owner, "Only the owner can send ETTO to this address");
        emit Received(from, address(this), amount);

    }
    	receive() external payable {
        require(msg.value >= 1 * 10 ** 18 && msg.value <= 10 * 10 ** 18, "The min is 1 MATIC, the max is 10 MATIC");
        address beneficiary = msg.sender;
        uint256 maticAmount = msg.value;
		buyTokens(beneficiary, maticAmount);
	}

    function token() public view returns (ERC777) {
        return ETTO;
    }

    function getMaticRaised() public view returns (uint256) {
        return maticRaised;
    }

    function lpContract() public view returns (address) {
        return lp;
    }

    function TokenBalance() public view returns(uint) {
        return IERC777(ETTO).balanceOf(address(this));
    }

    function buyTokens(address beneficiary, uint256 maticAmount) public payable nonReentrant {
        require(!hasPurchased[beneficiary], "Address has already purchased tokens");
        require(maticAmount >= 1 * 10 ** 18 && maticAmount <= 10 * 10 ** 18, "The min is 1 MATIC, the max is 10 MATIC");
        uint256 tokenAmount = getTokenAmount(maticAmount);
        maticRaised = maticRaised + maticAmount;
        deliverTokens(beneficiary, tokenAmount);
        emit Purchased(beneficiary, maticAmount, tokenAmount);
        forwardTokens(maticAmount);
        hasPurchased[beneficiary] = true;
    }

    function deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        ERC777(ETTO).transfer(beneficiary, tokenAmount);
    }

    function getTokenAmount(uint256 maticAmount) internal view returns (uint256) {
        return maticAmount.mul(rate);
    }

    function forwardTokens(uint256 maticAmount) internal {
        require(maticAmount >= 1 * 10 ** 18 && maticAmount <= 10 * 10 ** 18);
        (bool success, ) = payable(lp).call{value: maticAmount}("");
        require(success, "Failed to send Matic to AMM");
        emit LiquidityAdded(address(this), lp, maticAmount, maticRaised);
    }

}            