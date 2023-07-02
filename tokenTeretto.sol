// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC777/ERC777.sol";

contract Test_Redistributor_Token is ERC777 {
    using SafeMath for uint256;
    address public owner;
    address public LP;
    address public Presale;
    uint256 communityShare = 90;
    event PresaleSentToLP(address from, address Presale, address LP, uint256 presLP);
    event PresaleSentToB(address from, address Presale, address recipient, uint256 boughtAmount);
    event PresaleSentToR(address Presale, address redistributor, uint256 presRedAmount);
    event TransferSentToL(address from, address redistributor, uint256 redAmount);
    event TransferSent(address from, address recipient, uint256 amount);

    bool private presaleSet = false;
    bool private lpSet = false;

    constructor() ERC777("Teretto", "ETTO", new address[](0)) {
        _mint(msg.sender, 20000 * 10 ** 18, "", "");
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    function setPresale(address newPresale) public onlyOwner {
        require(!presaleSet, "Presale address has already been set.");
        Presale = newPresale;
        presaleSet = true;
    }

    function setLP(address newLP) public onlyOwner {
        require(!lpSet, "LP address has already been set.");
        LP = newLP;
        lpSet = true;
    }

    struct Destination 
    {
        address payable redistributor;
        string name;    
    }
    
    Destination[15] public destinations;
    uint256 private destinationCount;

    function addDestination(address payable redistributor, string memory name) 
        public onlyOwner 
    {
        require(destinationCount < 15, "Maximum number of destinations reached.");
        require(msg.sender == owner, "Only the owner can set this struct");
        destinations[destinationCount] = Destination(redistributor, name);
        destinationCount++;
    }

  
 function transfer(address recipient, uint256 amount) public override returns (bool) {
    address sender = msg.sender;
    
    bool specialAddress = false;
    for (uint i = 0; i < destinations.length; i++) {
        if (sender == destinations[i].redistributor || sender == owner || sender == LP || recipient == LP) {
            specialAddress = true;
        }
        if (recipient == destinations[i].redistributor || recipient == owner) {
            return false;
        }
    }

    
    if (msg.sender == Presale) {
        uint256 presRed = amount.mul(40) / 100;
        uint256 presLP = amount.mul(30) / 100;
        // send 40% to the redistributors
        for (uint i = 0; i < destinations.length; i++) { 
            _send(msg.sender, destinations[i].redistributor, presRed / destinations.length, "", "", true);
            emit PresaleSentToR(Presale, destinations[i].redistributor, presRed / destinations.length);
        }

        // send 30% to the LP
        _send(msg.sender, LP, presLP, "", "", true);
        emit PresaleSentToLP(msg.sender, Presale, LP, presLP);
     
        // send the remaining amount to the recipient
        _send(msg.sender, recipient, amount.sub(presRed).sub(presLP), "", "", true);
        emit PresaleSentToB(msg.sender, Presale, recipient, amount.sub(presRed).sub(presLP));
        return true;

    } else if (specialAddress) {
        // send the full amount to the recipient
        _send(msg.sender, recipient, amount, "", "", false);
        return true;

    } else {
        require(amount >= 1 * 10 ** 18);
        // calculate the community fee
        uint256 communityFee = amount.mul(communityShare) / 100;
        // send the community fee to the redistributors
        for (uint i = 0; i < destinations.length; i++) { 
            _send(msg.sender, destinations[i].redistributor, communityFee / destinations.length, "", "", true);
            emit TransferSentToL(msg.sender, destinations[i].redistributor, communityFee / destinations.length);    
        }

        // send the remaining amount to the recipient
        _send(msg.sender, recipient, amount.sub(communityFee), "", "", true);
        emit TransferSent(msg.sender, recipient, amount);
        return true;
    }
  }
}
