// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.1/contracts/token/ERC777/ERC777.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.1/contracts/utils/Strings.sol";
import "https://github.com/dapphub/ds-math/blob/master/src/math.sol";

contract LiquidityPool is IERC777Recipient, DSMath, ReentrancyGuard {

    address payable owner;
    IERC20 public token0;
    address public token1;
    address public presale;
    uint256 public reserve0;
    uint256 public reserve1;
    address public tokenAmount;
    address public maticAmount;
    event AddLiquidityToken1(address presale, uint256 amount1, address token1);
    event AddLiquidityToken0(address presale, uint256 amount0, IERC20 token0);
    event Bought(address indexed buyer, uint256 maticIn, uint256 tokenOut, uint256 maticPrice);
    event Sold(address indexed seller, uint256 tokenIn, uint256 maticOut, uint256 tokenPrice);

    bool private presaleSet = false;

    constructor(IERC20 _token0, address _token1) {
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24)
        .setInterfaceImplementer(address(this), keccak256("ERC777TokensRecipient"), address(this));
        token0 = _token0;
        token1 = _token1;
        tokenAmount = address(_token1);
        maticAmount = address(_token0);
        owner = payable(msg.sender);
        reserve1 = tokenBalance();
        reserve0 = balanceOf();
    }
    
    function setPresale(address _presale) external onlyOwner {
        require(_presale != address(0), "Invalid address");
        require(msg.sender == owner, "Only owner can set the Presale address");
        require(!presaleSet, "Presale address has already been set.");
        presale = _presale;
        presaleSet = true;
    }

    function tokensReceived(address operator, address from, address to, uint256 amount, bytes calldata userData, bytes calldata operatorData) external override 
    {
        require(operatorData.length >= 0, "OperatorData cannot be empty");
        require(userData.length >= 0, "UserData cannot be empty");
        require(to != address(0), "to cannot be the null address");
        require(operator != address(0), "Operator cannot be the null address");
        if(from != presale) {
            sell(payable(from), amount);
        } else if(from == presale) {
            require(amount >= 6 * 10 ** 18);
            reserve1 += amount;
            emit AddLiquidityToken1(presale, amount, token1);
        }
    }

       receive() external payable {
        if (msg.sender != presale) {
            buy(msg.sender, msg.value);
        } else if (msg.sender == presale || msg.sender == owner) {
            reserve0 += msg.value;
            emit AddLiquidityToken0(presale, msg.value, token0);
        }
    }

       modifier onlyOwner()
    {
        require(msg.sender == owner);
    _;
    }
   
    function getmaticToToken() public view returns (uint256) {
    require(reserve0 >= 1 * 10 ** 18 && reserve1 >= 1 * 10 ** 18, "AMM: INSUFFICIENT_LIQUIDITY");
    uint256 maticToToken = DSMath.wdiv(reserve0, reserve1);
    return maticToToken;
    }
    
    function gettokenToMatic() public view returns (uint256) {
    require(reserve1 >= 1 * 10 ** 18 && reserve0 >= 1 * 10 ** 18, "AMM: INSUFFICIENT_LIQUIDITY");
    uint256 tokenToMatic = DSMath.wdiv(reserve1, reserve0);
    return tokenToMatic;
    }

    function sell(address payable seller, uint256 tokenIn) public payable nonReentrant {
      prevalidateTrading(tokenIn);
      uint256 maticOut = DSMath.wmul(getmaticToToken(), tokenIn);
      deliverMatic(seller, maticOut);
      emit Sold(seller, tokenIn, maticOut, gettokenToMatic());
      reserve1 = add(reserve1, tokenIn);
      reserve0 = sub(reserve0, maticOut);
    }

      function prevalidateTrading(uint256 tokenIn) internal view {
         require(tokenAmount == token1, "AMM: INVALID_TOKEN");
         require(tokenIn >= 100 * 10 ** 18);
    }

    function buy(address buyer, uint256 maticIn) public payable nonReentrant{
      prevalidatePurchase(maticIn);
      uint256 tokenOut = DSMath.wmul(gettokenToMatic(), maticIn);
      deliverTokens(buyer, tokenOut);
      emit Bought(buyer, maticIn, tokenOut, getmaticToToken());
      reserve0 = add(reserve0, maticIn);
      reserve1 = sub(reserve1, tokenOut);
    }

      function prevalidatePurchase(uint256 maticIn) internal view {
         require(maticAmount == address(token0), "AMM: INVALID_TOKEN");
         require(maticIn >= 1 * 10 ** 18 , "AMM: INSUFFICIENT_SWAP_AMOUNT");
    }

    function deliverTokens(address buyer, uint256 tokenOut) internal {
        ERC777(token1).transfer(buyer, tokenOut);
    }

    function deliverMatic(address payable seller, uint256 maticOut) internal {
       seller.transfer(maticOut);
    }

    function tokenBalance() public view returns(uint256) {
        return ERC777(token1).balanceOf(address(this));
    }

    function balanceOf() public view returns(uint256) {
        return IERC20(token0).balanceOf(address(this));
    }
}