pragma solidity ^0.8.10;

import "./AccountantInterfaces.sol";
import "../ExponentialNoError.sol";
import "../ErrorReporter.sol";

contract AccountantDelegate is AccountantInterface, ExponentialNoError, TokenErrorReporter, ComptrollerErrorReporter{
		
	/**
      * @notice Method used to initialize the contract during delegator contructor
      * @param cnoteAddress_ The address of the CNoteDelegator
	  * @param noteAddress_ The address of the note contract
	  * @param comptrollerAddress_ The address of the comptroller contract
      */
	function initialize( address treasury_, address cnoteAddress_, address noteAddress_, address comptrollerAddress_) public {

		require(msg.sender == admin, "AccountantDelegate::initialize: only admin can call this function");
		require(noteAddress_ != address(0), "AccountantDelegate::initialize: note Address invalid");

		treasury = treasury_; // set the current treasury address (address of TreasuryDelegator)	
		address[] memory MarketEntered = new address[](1); // first entry into lending market
		MarketEntered[0] = cnoteAddress_;
		
		comptroller = ComptrollerInterface(comptrollerAddress_);
		note = Note(noteAddress_);
		cnote = CNote(cnoteAddress_);

		note._mint_to_Accountant(msg.sender); // mint note.totalSupply() to this address
		require(note.balanceOf(msg.sender) == note._initialSupply(), "AccountantDelegate::initiatlize: Accountant has not received payment");

		uint[] memory err = comptroller.enterMarkets(MarketEntered); // check if market entry returns without error
		if (err[0] != 0) {
			fail(Error.MARKET_NOT_LISTED, FailureInfo.SUPPORT_MARKET_EXISTS);
		}
		emit AcctInit(cnoteAddress_);

		cnote._setAccountantContract(payable(this));

		note.approve(cnoteAddress_, type(uint).max); // approve lending market, to transferFrom Accountant as needed
	}
    
	/**
	 * @notice Method to supply markets
	 * @param amount the amount to supply
	 * @return uint error code from CNote mint()
	 */
    function supplyMarket(uint amount) external override returns(uint) {
		require(msg.sender == address(cnote), "AccountantDelegate::supplyMarket: Only the CNote contract can supply market");
		uint err =  cnote.mint(amount);
		emit AcctSupplied(amount, uint(err));
		return err;
     }

    /**
	 * @notice Method to redeem account CNote from lending market 
	 * @param amount Amount to redeem (in CNote)
	 * @return uint Amount of cnote redeemed (amount * exchange rate)
	 */
    function redeemMarket(uint amount) external override returns(uint) {
		require(msg.sender == address(cnote), "AccountantDelegate::redeemMarket: Only the CNote contract can redeem market");

		Exp memory expRate = Exp({mantissa: cnote.exchangeRateStored()}); // return exchangeRate scaled by 1e18

		uint amtToRedeem = div_(amount, expRate); // convert exchangeRateStored Internal to Exp, multiply by scalar amount, and truncate, to return correct amount to redeem

		return cnote.redeem(amtToRedeem); // redeem the amount of Note calculated via current CNote -> Note exchange rate
    }


	/**
	 * @notice Method to sweep interest earned from accountant depositing note in lending market to the treasury
	 * @return uint 0
	 */
    function sweepInterest() external override returns(uint) {
		
		uint noteBalance = note.balanceOf(address(this));
		uint CNoteBalance = cnote.balanceOf(address(this));

		Exp memory expRate = Exp({mantissa: cnote.exchangeRateStored()}); // obtain exchange Rate from cNote Lending Market as a mantissa (scaled by 1e18)
		uint cNoteConverted = mul_ScalarTruncate(expRate, CNoteBalance); //calculate truncate(cNoteBalance* mantissa{expRate})
		uint noteDifferential = sub_(note.totalSupply(), noteBalance); //cannot underflow, subtraction first to prevent against overflow, subtraction as integers

		require(cNoteConverted >= noteDifferential, "Note Loaned to LendingMarket must increase in value");
		
		uint amtToSweep = sub_(cNoteConverted, noteDifferential);

		note.transfer(treasury, amtToSweep);

		cnote.transfer(address(0), CNoteBalance);

		return 0;
    }
    
    receive() external override payable {}
}
