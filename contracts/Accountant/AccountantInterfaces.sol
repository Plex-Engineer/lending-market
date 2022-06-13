pragma solidity ^0.8.10;
import "../Note.sol";
import "../CNote.sol";
import "../ComptrollerInterface.sol";

contract AccountantDelegatorStorage {

    address public admin; // admin address (Timelock)
    address public implementation; // implementation address

}

contract AccountantStorageV1 is AccountantDelegatorStorage{
    
    event AcctInit(address lendingMarketAddress);
	event AcctSupplied(uint amount, uint err);
    
    Note public note; // note address
    CNote public cnote; // lending market address
    ComptrollerInterface public comptroller; // comptroller address
    address public treasury; // treasury address
}

abstract contract AccountantDelegatorInterface {
    event NewImplementation(address oldImplementation, address newImplementation);
    function _setImplementation(address implementation_) public virtual;
}

abstract contract AccountantInterface is AccountantStorageV1 {
    function supplyMarket(uint amount) external virtual returns(uint);
    function redeemMarket(uint amount) external virtual returns(uint);
    function sweepInterest() external virtual returns(uint);
    receive() external virtual payable;
}