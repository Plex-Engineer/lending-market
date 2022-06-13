pragma solidity ^0.8.10;

import "./CErc20Delegate.sol";
import "./Accountant/AccountantInterfaces.sol";
import "./Treasury/TreasuryInterfaces.sol";
import "./ErrorReporter.sol";

contract CNote is CErc20Delegate {

    event AccountantSet(address accountant, address accountantPrior);

    AccountantInterface private _accountant; // accountant private _accountant = Accountant(address(0));

    function _setAccountantContract(address payable accountant_) public {
        if (address(_accountant) != address(0)){
            require(msg.sender == admin, "CNote::_setAccountantContract:Only admin may call this function");
        }
        emit AccountantSet(accountant_, address(_accountant));
	    _accountant = AccountantInterface(accountant_);
        admin = accountant_;
    }
    
    function getAccountant() external view returns(address) {
        return address(_accountant);
    }

    /**
      * @notice Users borrow assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      */
    function borrowFresh(address payable borrower, uint borrowAmount) internal override {
        /* Fail if borrow not allowed */
        uint allowed = comptroller.borrowAllowed(address(this), borrower, borrowAmount);
        if (allowed != 0) {
            revert BorrowComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert BorrowFreshnessCheck();
        }

	    require(getCashPrior() == 0, "CNote::borrowFresh:Impossible reserves in CNote market Place");

	    require(address(_accountant) != address(0), "CNote::borrowFresh:Accountant has not been initialized");
	
	    /*Protocol always has a balance of 0 Note, thus the accountant must mint borrowAmount tokens */
        uint err = _accountant.supplyMarket(borrowAmount);
        
        if (err != 0) {
            revert AccountantSupplyError(borrowAmount);
        }

        require(getCashPrior() == borrowAmount, "CNote::borrowFresh:Error in Accountant supply");
	
	
        /*
         * We calculate the new borrower and total borrow balances, failing on overflow:
         *  accountBorrowsNew = accountBorrows + borrowAmount
         *  totalBorrowsNew = totalBorrows + borrowAmount
         */
        uint accountBorrowsPrev = borrowBalanceStoredInternal(borrower);
        uint accountBorrowsNew = accountBorrowsPrev + borrowAmount;
        uint totalBorrowsNew = totalBorrows + borrowAmount;

        /////////////////////////   
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         * We invoke doTransferOut for the borrower and the borrowAmount.
         *  Note: The cToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the cToken borrowAmount less of cash.
         *  doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
         */
        doTransferOut(borrower, borrowAmount);
	    require(getCashPrior() == 0,"CNote::borrowFresh: Error in doTransferOut, impossible Liquidity in LendingMarket");
	//Amount minted by Accountant is always flashed from account
	
	/* We write the previously calculated values into storage */
        accountBorrows[borrower].principal = accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        /* We emit a Borrow event */
        emit Borrow(borrower, borrowAmount, accountBorrowsNew, totalBorrowsNew);
    }

    /**
     * @notice Borrows are repaid by another user (possibly the borrower).
     * @param payer the account paying off the borrow
     * @param borrower the account with the debt being payed off
     * @param repayAmount the amount of undelrying tokens being returned
     * @return (uint, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function repayBorrowFresh(address payer, address borrower, uint repayAmount) internal override returns(uint){
        /* Fail if repayBorrow not allowed */
        uint allowed = comptroller.repayBorrowAllowed(address(this), payer, borrower, repayAmount);
        if (allowed != 0) {
            revert BorrowComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert RepayBorrowFreshnessCheck();
        }
        /* We fetch the amount the borrower owes, with accumulated interest */
        uint accountBorrowsPrev = borrowBalanceStoredInternal(borrower);

        /* If repayAmount == -1, repayAmount = accountBorrows */
        uint repayAmountFinal = repayAmount == type(uint).max ? accountBorrowsPrev : repayAmount;

        //this cannot be a require statement, it must be accounted for if this is the case
        require(getCashPrior() == 0, "CNote::repayBorrowFresh:Liquidity in Note Lending Market is always flashed");
        //make sure that this is remedied
	
	
	
	/////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)
        /*
         * We call doTransferIn for the payer and the repayAmount
         *  Note: The cToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the cToken holds an additional repayAmount of cash.
         *  doTransferIn reverts if anything goes wrong, since we can't be sure if side effects occurred.
         *   it returns the amount actually transferred, in case of a fee.
         */
        uint actualRepayAmount = doTransferIn(payer, repayAmount);
        require(getCashPrior() >= actualRepayAmount, "CNote::repayBorrowFresh: doTransferIn supplied incorrect amount"); //sanity check that Accountant has some thing to redeem
        
        //underlying.balanceOf(address(this)) == repayAmount;
        uint amtRedeemed = getCashPrior();
        uint err = _accountant.redeemMarket(amtRedeemed);
        if (err != 0) {
            revert AccountantRedeemError(amtRedeemed);
        }

        
        if (getCashPrior() != 0) {
            address payable acctAddr = payable(_accountant);
            doTransferOut(acctAddr, getCashPrior()); //sanity check to ensure that there is not liquidity left in the lending market
            //account for any errors in the CNote ->Note conversion in the Accounting contract
        }

        require(getCashPrior() == 0, "CNote::repayBorrowFresh: Error in Accountant.redeemMarket");
        
        /*
         * We calculate the new borrower and total borrow balances, failing on underflow:
         *  accountBorrowsNew = accountBorrows - actualRepayAmount
         *  totalBorrowsNew = totalBorrows - actualRepayAmount
         */
        uint accountBorrowsNew = accountBorrowsPrev -  actualRepayAmount;

        uint totalBorrowsNew = totalBorrows - actualRepayAmount;

        /* We write the previously calculated values into storage */
        accountBorrows[borrower].principal = accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        /* We emit a RepayBorrow event */
        emit RepayBorrow(payer, borrower, actualRepayAmount, accountBorrowsNew, totalBorrowsNew);

        /* We call the defense hook */
        // unused function
        // comptroller.repayBorrowVerify(address(this), payer, borrower, vars.actualRepayAmount, vars.borrowerIndex);

        return actualRepayAmount;
    }

    /**
      * @notice User supplies assets into the market and receives cTokens in exchange
     * @dev Assumes interest has already been accrued up to the current block
     * @param minter The address of the account which is supplying the assets
     * @param mintAmount The amount of the underlying asset to supply
     */
    function mintFresh(address minter, uint mintAmount) internal override {
        if (minter == address(_accountant)) {
            CToken.mintFresh(address(_accountant), mintAmount);
            return;
        }
        
        /* Fail if mint not allowed */
        uint allowed = comptroller.mintAllowed(address(this), minter, mintAmount);
        if (allowed != 0) {
            revert MintComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert MintFreshnessCheck();
        }


        Exp memory exchangeRate = Exp({mantissa: exchangeRateStoredInternal()});

	    require(getCashPrior() == 0, "CNote::mintFresh: Any Liquidity in the Lending Market is flashed");
        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         *  We call `doTransferIn` for the minter and the mintAmount.
         *  Note: The cToken must handle variations between ERC-20 and ETH underlying.
         *  `doTransferIn` reverts if anything goes wrong, since we can't be sure if
         *  side-effects occurred. The function returns the amount actually transferred,
         *  in case of a fee. On success, the cToken holds an additional `actualMintAmount`
         *  of cash.
         */
        uint actualMintAmount = doTransferIn(minter, mintAmount);
	//Liquidity in Lending Market
	
        require(getCashPrior() == actualMintAmount, "CNote::mintFresh: Error in doTransferIn, CNote reserves >= mint Amount"); //sanity check that Accountant has some thing to redeem
        
        //underlying.balanceOf(address(this)) == repayAmount;
        uint amtMinted = getCashPrior();
        uint err = _accountant.redeemMarket(amtMinted);
        if (err != 0) {
            revert AccountantRedeemError(amtMinted);
        }

        
        if (getCashPrior() != 0) {
            address payable AcctAddr = payable(_accountant);
            doTransferOut(AcctAddr, getCashPrior());  //account for any unprecedented liquidity in the CNote ->Note conversion in the Accounting contract
        }

        require(getCashPrior() == 0);
        /*
         * We get the current exchange rate and calculate the number of cTokens to be minted:
         *  mintTokens = actualMintAmount / exchangeRate
         */

        uint mintTokens = div_(actualMintAmount, exchangeRate);

        /*
         * We calculate the new total supply of cTokens and minter token balance, checking for overflow:
         *  totalSupplyNew = totalSupply + mintTokens
         *  accountTokensNew = accountTokens[minter] + mintTokens
         */
        /* We write previously calculated values into storage */
        totalSupply = totalSupply + mintTokens;
        accountTokens[minter] = accountTokens[minter] + mintTokens; 

        /* We emit a Mint event, and a Transfer event */
        emit Mint(minter, actualMintAmount, mintTokens);
        emit Transfer(address(this), minter, mintTokens);
    }
     
    /**
     * @notice User redeems cTokens in exchange for the underlying asset
     * @dev Assumes interest has already been accrued up to the current block
     * @param redeemer The address of the account which is redeeming the tokens
     * @param redeemTokensIn The number of cTokens to redeem into underlying (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     * @param redeemAmountIn The number of underlying tokens to receive from redeeming cTokens (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     */
    function redeemFresh(address payable redeemer, uint redeemTokensIn, uint redeemAmountIn) internal override {
        if (redeemer == address(_accountant)) {
            CToken.redeemFresh(payable(_accountant), redeemTokensIn, 0);
            return;
        }
        
        require(redeemTokensIn == 0 || redeemAmountIn == 0, "one of redeemTokensIn or redeemAmountIn must be zero");
        /* exchangeRate = invoke Exchange Rate Stored() */
        Exp memory exchangeRate = Exp({mantissa: exchangeRateStoredInternal()});

        uint redeemTokens; 
        uint redeemAmount;

        /* If redeemTokensIn > 0: */
        if (redeemTokensIn > 0) {
            /*
             * We calculate the exchange rate and the amount of underlying to be redeemed:
             *  redeemTokens = redeemTokensIn
             *  redeemAmount = redeemTokensIn x exchangeRateCurrent
             */
            redeemTokens = redeemTokensIn;

            redeemAmount = mul_ScalarTruncate(exchangeRate, redeemTokensIn);
        } else {
            /*
             * We get the current exchange rate and calculate the amount to be redeemed:
             *  redeemTokens = redeemAmountIn / exchangeRate
             *  redeemAmount = redeemAmountIn
             */

            redeemTokens = div_(redeemAmountIn, exchangeRate);

            redeemAmount = redeemAmountIn;
        }

        /* Fail if redeem not allowed */
        uint allowed = comptroller.redeemAllowed(address(this), redeemer, redeemTokens);
        if (allowed != 0) {
            revert RedeemComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert RedeemTransferOutNotPossible();
        }

        /*
         * We calculate the new total supply and redeemer balance, checking for underflow:
         *  totalSupplyNew = totalSupply - redeemTokens
         *  accountTokensNew = accountTokens[redeemer] - redeemTokens
         */

	    require(getCashPrior() == 0, "CNote::redeemFresh, LendingMarket has > 0 Cash before Accountant Supplies");
	
        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         * We invoke doTransferOut for the redeemer and the redeemAmount.
         *  Note: The cToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the cToken has redeemAmount less of cash.
         *  doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
         */
	
        /*Protocol always has a balance of 0 Note, thus the accountant must mint borrowAmount tokens */
        uint err = _accountant.supplyMarket(redeemAmount);
        /* */
        if (err != 0) {
            revert AccountantSupplyError(redeemAmount);
        }

        require(getCashPrior() == redeemAmount, "CNote::redeemFresh: Accountant has supplied incorrect Amount");

        doTransferOut(redeemer, redeemAmount);
	
        /* We write previously calculated values into storage */
        totalSupply = totalSupply - redeemTokens;
        accountTokens[redeemer] = accountTokens[redeemer] - redeemTokens;

        /* We emit a Transfer event, and a Redeem event */
        emit Transfer(redeemer, address(this), redeemTokens);
        emit Redeem(redeemer, redeemAmount, redeemTokens);

        /* We call the defense hook */
        comptroller.redeemVerify(address(this), redeemer, redeemAmount, redeemTokens);
    }

    /*** Reentrancy Guard ***/
    //
    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     */
    modifier nonReentrant() override {
        if (msg.sender != address(_accountant)) {
            require(_notEntered, "re-entered");
        }
        _notEntered = false;
        _;
        _notEntered = true; // get a gas-refund post-Istanbul
    }
}