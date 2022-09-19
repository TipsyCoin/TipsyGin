# TipsyGin
-Smart contract code for TipsyCoin's Gin token. Uses EIP712 for multi-chain mint
-Based on T11's Solmate EIP2616 contract here: https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol-
-Uses a similiar method as 'permit' to allow signing wallets to mint coins on any chain via our upcoming bridge, TipsyServer

## Hardhat Testing Reqs
- Testing Gin.sol, as well as the integration of TipsyStake.sol with Gin.sol now handeling the minting of staking rewards
- OwnableKeepable.sol was already audited last time, and Solmate_modified.sol is abstract and derived from t11's Solmate contract above (already audited too)

### Key functions to test
- permitContract(), permitSigner(), revokeSigner(), revokeContract(), setRequiredSigs(), setPause(), mintTo(), deposit()
- testMint provided for testing convenience, allows you to mint Gin to anyone. This function has changed names from mintTo(). Because mintTo() is now a real function.
- Test deposit() last, because I'm still going to make changes to it
- Testing functions (don't worry about):
- _keccakCheckak(), _keccakInner(), chainId(), return_max(), _testInit()

### Most important function to test is mintTo(). This is what TipsyStake platform calls when doing mints 
(https://github.com/TipsyCoin/TipsyVerseStaking/blob/main/contracts/Stakingv1.sol).
- After Gin.sol is deployed, make sure you permitContract(TipsyStake.sol address)
- After Stakingv1.sol is deployed, make sure you setGinAddress(Gin.sol address)
- After both are set, Harvesting, Staking, or Unstaking on TipsyStake should call mintTo function on Gin.sol and increase their token balance
