pragma solidity ^0.8.10;

import "./ERC20.sol";

contract Note is ERC20 {
    address public accountant = address(0);
    address public admin;

    constructor(uint amount) ERC20("Note", "NOTE", amount) {
        admin = msg.sender;
    }

    function _mint_to_Accountant(address accountantDelegator) external {
        if (accountant == address(0)) {
            _setAccountantAddress(msg.sender);
        }
        require(msg.sender == accountant, "Note::_mint_to_Accountant: ");
        _mint(msg.sender, type(uint).max);
    }

    function RetAccountant() public view returns(address) {
	    return accountant;
    }
    
    function _setAccountantAddress(address accountant_) internal {
        if(accountant != address(0)) {
            require(msg.sender == admin, "Note::_setAccountantAddress: Only admin may call this function");
        }
        accountant = accountant_;
        admin = accountant;
    }
}
