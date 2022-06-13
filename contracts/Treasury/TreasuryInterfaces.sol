pragma solidity ^0.8.10;

import "../EIP20Interface.sol";
import "../IProposal.sol"; 

contract TreasuryDelegatorStorage {
    address public admin;     // admin address (Timelock)
    address public implementation; // implementation address (TreasuryDelegate)
}

contract TreasuryStorageV1 is TreasuryDelegatorStorage {
    EIP20Interface public note; // note interface, for handling transfers and querying balance
    IProposal public unigov; // unigov Interface for handling proposals
}

abstract contract TreasuryDelegatorInterface {
    event NewImplementation(address oldImplementation, address newImplementation);
    function _setImplementation(address implementation_) public virtual;
    receive() external virtual payable;
    fallback() external virtual;
}

abstract contract TreasuryInterface is TreasuryStorageV1 {
    function queryCantoBalance() external virtual view returns(uint);
    function queryNoteBalance() external virtual view returns(uint);
    function sendFund(address recipient, uint amount, string calldata denom) external virtual;
}