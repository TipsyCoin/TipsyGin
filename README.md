# TipsyGin
- Gin is TipsyVerse's cross-chain Staking and block-chain backed in-game currency.
- Gin is a standard ERC20 + EIP2612, but with affordances for our Staking platform to mint tokens via an interface, as well as our bridge and game servers to sign messages off-chain and mint tokens across any deployed chain via a relay.
- Smart contract code for TipsyCoin's cross-chain Staking and Game reward token, Gin. Uses EIP712 / EIP2612 style signing (for permit) with multi-sig for safer cross-chain mints.
- ERC20 Based on T11's Solmate contract here: https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol
- Solmate has been audited before, but we've made changes for Gin. Their latest available audit is here: https://github.com/transmissions11/solmate/blob/main/audits/v6-Fixed-Point-Solutions.pdf
- Multisig verification is based on Gnosis Safe contracts https://github.com/safe-global/safe-contracts/blob/main/contracts/GnosisSafe.sol

## Contracts
- contracts/Gin.sol the main ERC20 contract to audit. Inherits from our modified Solmate. Contains the permitted contracts / signers logic, deposit logic and events (for upcoming cross-chain functionality), plus the multi-sig mint method.
- contracts/Solmate_modified.sol T11's Solmate ERC20 contract with some modifications to allow Gin to work properly. Specific changes detailed in the sol file, but an example includes adding proxy support by stripping out contrstructor logic.
- contracts/OwnableKeepable.sol Ownership contract with a separate Keeper role for maintenance. Owner will be transferred to a 2/3 multi-sig (0x884C908ea193B0Bb39f6A03D8f61C938F862e153). Keeper will be held by the EOA TipsyCoin deployer (0xbeefa0b80f7ac1f1a5b5a81c37289532c5d85e88)
- Contracts will use transparent upgradeable proxy pattern (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/transparent/TransparentUpgradeableProxy.sol), hence the use of initialize() functions.
- Proxy Admin will be held by separate 3/5 multi-sig (0xb4620C524245c584C5C2Ba79FD20CeB926FBd418)
- Contracts should compile to the same bytecode across multiple chains, to ease cross-chain deployment and management logistics.

## Testing
- We've created a number of HardHat tests, which you can see here: https://github.com/TipsyCoin/TipsyGin/tree/main/test
- A number of helpful test functions for HardHat have been removed from the prod branch (e.g. a testMint function). If you think these would aid your testing, please pull Main
- HardHat also includes integration tests for our Staking platform. If you want to see or test that code, it's publicly available here: https://github.com/TipsyCoin/TipsyVerseStaking/tree/main/contracts
- The integration tests for TipsyStake + Gin are also in the Staking repo, here: https://github.com/TipsyCoin/TipsyVerseStaking/tree/main/test

## MultisigMint
- Calculating correct hashes for our multi-sig stuff might be hard, so there is a Python script we've created to verify multi-sig mints can be calcuated off-chain and submitted to the contract successfully (https://github.com/TipsyCoin/TipsyGin/tree/main/PythonTest)
- You can also see an example on a Testnet chain here: https://testnet.bscscan.com/tx/0x67337fa58a21531f3d54d7ce73ad064bfb03d5d4da424c2b125df00d4b5fac7d
- In future we plan to monitor the deposit events from this contract with our bridging server
- The bridge will consist of two or more AWS servers that will separately verify the transaction, transmit their sigs to the 'lead' server, which will relay a mint transaction on the appropriate chain via the gelato relay network
- Our upcoming game will also have servers that can monitor deposit events to chainId 0. This will allow deposits and mints from our game server to any supported chain
