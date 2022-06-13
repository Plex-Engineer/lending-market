# Lending Market
## Overview
- The Lending Market is a Compound fork with modified governance. 

## Testing:
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
