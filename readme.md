# Lending Market

## Note on admin and delegation mechanics:
- In all delegate contracts (AccountantDelegate, TreasuryDelegate, GovernorBravoDelegate, etc), the initialize function has the following require statement:

    `require(msg.sender == admin);`

- Since this is a Delegate contract, the Delegator (AccountantDelegator, TreasuryDelegator, etc) will be calling these functions via a delegatecall. 
- During these calls, the admin is referring to the admin of the Delegator, which is stored in the Interface contract. 
- Delegate contracts simply hold the execution logic, but the admin, implementation, and all other storage variables are that of the Delegator. 
- These contracts are designed this way for future upgradeability. We can simply deploy a new Delegate contract and set it as the new implementation to add or remove functionality.
- Setting a new Delegate implementation can be done through governance. 

## Overview
- The Lending Market is a Compound fork with modified governance. 

## Modifications to Compound
- Removed Comp Token.
- Removed Comp token references in GovernorBravo and Comptroller.
- Dripping of Wrapped-Canto (ERC-20 version of native token Canto) to Suppliers of Lending. Market instead of Comp token.
- Governance Modifications
- Created custom Unigov Interface with Proposal struct and function that takes in a proposal ID and returns the correctly mapped Proposal struct.

```
interface UnigovInterface{
    struct Proposal {
        // @notice Unique id for looking up a proposal
        uint id;
        string title;
        
        string desc;
        // @notice the ordered list of target addresses for calls to be made
        address[] targets;
	
        uint[] values;
        // @notice The ordered list of function signatures to be called
        string[] signatures;
        // @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;
    }
  function QueryProp(uint propId) external view returns(Proposal memory);
}
```

- Modified Queue function to query a proposal from the Map Contract and call queueOrRevertInternal on the queried proposal to send to TimeLock.

```
function queue(uint proposalId) external {
	    // address of map contract; used to query proposals from cosmos SDK
        address mapContractAddress = 0x30E20d0A642ADB85Cb6E9da8fB9e3aadB0F593C0;
        // attach to contract using interface defined above
        UnigovInterface unigov = UnigovInterface(mapContractAddress);
        
        // call QueryProp method here
        UnigovInterface.Proposal memory prop = unigov.QueryProp(proposalId);
	
        // TODO: need to look into definition of timelock delay - make sure it meets our requirements
        uint eta = add256(block.timestamp, timelock.delay());
        for (uint i = 0; i < prop.targets.length; i++) {
            queueOrRevertInternal(prop.targets[i], prop.values[i], prop.signatures[i], prop.calldatas[i], eta);
        }
        emit ProposalQueued(proposalId, eta);
    }
```

### Comptroller Modifications
- Modified the grantCompInternal function to enable the transfer of any EIP20-Interface Token and removed reference to Comp() object.

## Testing
A full suite of unit tests using hardhat and saddle are provided for the lending Market.

### Saddle
- Ensure that node version 12 is being used, and yarn(npm) install
- Ensure that the solc 0.8.10 compiler is being natively used,
    - wget [https://github.com/ethereum/solidity/releases/download/v0.8.10/solc-static-linux](https://github.com/ethereum/solidity/releases/download/v0.8.10/solc-static-linux) -O /bin/solc && chmod +x /bin/solc
- npx saddle compile && npx saddle test

### Hardhat
- Ensure that node version 16 is being used,
- yarn/npm install
- npx hardhat test ./tests/Treasury/canto/….test.ts

### Deploy Scripts:
- Detailed deployment scripts may be found in the lending-market/deploy/ 
- These deployment scripts may be deployed via editing the hardhat.config.ts config file
- You may edit these contracts, or use the scripts we have defined
    - npx hardhat deploy —network …
