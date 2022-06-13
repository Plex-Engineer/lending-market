pragma solidity ^0.8.10;

import "../IProposal.sol";
import "../EIP20Interface.sol";
import "../Lens/CompoundLens.sol";
import "../Comptroller.sol";
import "./TreasuryInterfaces.sol";

contract TreasuryDelegate is TreasuryInterface {

    /**
     * @notice Initializes the note contract
     * @param note_ The address of note ERC20 contract
     */
    function initialize(address note_) public {
        require(msg.sender == admin);
	    require(note_ != address(0));
	    note = EIP20Interface(note_);
    }

    /**
     * @notice Method to query current balance of CANTO in the treasury
     * @return treasuryCantoBalance the canto balance
     */
    function queryCantoBalance() external view override returns (uint) {
        uint treasuryCantoBalance = address(this).balance;
        return treasuryCantoBalance;
    }

    /**
     * @notice Method to query current balance of NOTE in the treasury 
     * @return treasuryNoteBalance the note balance 
     */
    function queryNoteBalance() external view override returns (uint) {
        uint treasuryNoteBalance = note.balanceOf(address(this));
        return treasuryNoteBalance;
    }

    /**
     * @notice Method to send treasury funds to recipient
     * @dev Only the admin can call this method (Timelock contract)
     * @param recipient Address receiving funds
     * @param amount Amount to send
     * @param denom Denomination of fund to send 
     */
    function sendFund(address recipient, uint amount, string calldata denom) external override {
        require(msg.sender == admin, "Treasury::sendFund can only be called by admin");
        address payable to = payable(recipient);

        // sending CANTO
        if (keccak256(bytes(denom)) == keccak256(bytes("CANTO"))) {
            to.transfer(amount);
        } 
        // sending NOTE
        else if (keccak256(bytes(denom)) == keccak256(bytes("NOTE"))) {
            note.transfer(recipient, amount);
        }   
    }
}
