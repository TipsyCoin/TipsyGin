// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "./Solmate_modified.sol";
import "./OwnableKeepable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
//import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Gin is SolMateERC20, Ownable, Pausable, Initializable
{
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event ChainSupport(uint indexed chainId, bool indexed supported);
    event ContractPermission(address indexed contractAddress, bool indexed permitted);
    event SignerPermission(address indexed signerAddress, bool indexed permitted);
    event RequiredSigs(uint8 indexed oldAmount, uint8 indexed newAmount);
    event Deposit(address indexed from, uint256 indexed amount, uint256 sourceChain, uint256 indexed toChain);
    event Withdrawal(address indexed to, uint256 indexed amount, bytes32 indexed depositID);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 => bool) public supportedChains;
    uint8 public requiredSigs;

    /*//////////////////////////////////////////////////////////////
                                INITILALIZATION
    //////////////////////////////////////////////////////////////*/

    //Testing Only
    /*
    function _testInit() external {
        initialize(msg.sender, msg.sender, address(this));
        permitSigner(address(msg.sender));
        permitSigner(address(0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf));//this is the address for the 0x000...1 priv key
        permitSigner(address(0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF));//this is the address for the 0x000...2 priv key
    }*/

    function initialize(address owner_, address _keeper, address _stakingContract) public initializer {
            require(decimals == 18, "Init: Const check DECIMALS");
            require(keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked("Gin")), "Init: Const check NAME");
            require(keccak256(abi.encodePacked(symbol)) == keccak256(abi.encodePacked("$gin")), "Init: Const check SYMBOL");
            require(MIN_SIGS == 2, "Init: Const check SIGS");
            require(_keeper != address(0), "Init: keeper can't be 0 address");
            require(owner_ != address(0), "Init: owner can't be 0 address");
            keeper = _keeper;
            //Owner will be gnosis safe multisig
            initOwnership(owner_);
            INITIAL_CHAIN_ID = block.chainid;
            INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
            setRequiredSigs(MIN_SIGS);
            //Use address 0 for chains that don't have staking contract deployed
            if (_stakingContract != address(0)) permitContract(_stakingContract);
    }

    /*//////////////////////////////////////////////////////////////
                                PRIVILAGED
    //////////////////////////////////////////////////////////////*/

    function permitContract(address _newSigner) public onlyOwner returns (bool) {
        emit ContractPermission(_newSigner, true);
        return _addContractMinter(_newSigner);
    }

    function permitSigner(address _newSigner) public onlyOwner returns (bool) {
        emit SignerPermission(_newSigner, true);
        return _addMintSigner(_newSigner);
    }

    function revokeSigner(address _newSigner) public onlyOwnerOrKeeper returns (bool) {
        emit SignerPermission(_newSigner, false);
        return _removeMintSigner(_newSigner);
    }
    //This one is only owner, because it could break Tipsystake.
    function revokeContract(address _newSigner) public onlyOwner returns (bool) {
        emit ContractPermission(_newSigner, false);
        return _removeContractMinter(_newSigner);
    }

    function setRequiredSigs(uint8 _numberSigs) public onlyOwner returns (uint8) {
        require(_numberSigs >= MIN_SIGS, "SIGS_BELOW_MINIMUM");
        emit RequiredSigs(requiredSigs, _numberSigs);
        requiredSigs = _numberSigs;
        return _numberSigs;
    }

    function setSupportedChain(uint256 _chainId, bool _supported) external onlyOwnerOrKeeper returns(uint256, bool) {
        require(_chainId != block.chainid, "TO_FROM_CHAIN_IDENTICTAL");
        supportedChains[_chainId] = _supported;
        emit ChainSupport(_chainId, _supported);
        return (_chainId, _supported);
    }

    function setPause(bool _paused) external onlyOwnerOrKeeper {
        if (_paused == true) _pause();
        else _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                                TIPSYSTAKE INTEGRATION
    //////////////////////////////////////////////////////////////*/
    function mintTo(address _to, uint256 _amount) public whenNotPaused returns (bool) {
        require(contractMinters[msg.sender] == true, "MINTTO_FOR_TIPSYSTAKE_CONTRACTS_ONLY");
        _mint(_to, _amount);
        emit Mint(msg.sender, _to, _amount);
        return true; //return bool required for our staking contract to function
    }

    /*//////////////////////////////////////////////////////////////
                                BRIDGE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    //Deposit from address to the given chainId. Our bridge will pick the Deposit event up and MultisigMint on the associated chain
    //Checks to ensure chainId is supported (ensure revent when no supported chainIds before bridge is live)
    //Does a standard transferFrom to ensure user approves this contract first. (Prevent accidental deposit, since this method is destructive to tokens)
    //Likely to use ChainID 0 to indicate tokens should be transfered to our game server
    function deposit(uint256 _amount, uint256 toChain) external whenNotPaused returns (bool) {
        require(supportedChains[toChain], "CHAIN_NOTYET_SUPPORTED");
        require(transferFrom(msg.sender, address(this), _amount), "DEPOSIT_FAILED_CHECK_BAL_APPROVE");
        _burn(address(this), _amount);
        emit Deposit(msg.sender, _amount, block.chainid, toChain);
        return true;
    }

    //MultiSig Mint. Used so server/bridge can sign messages off-chain, and transmit via relay network
    //Also used by the game. So tokens can be minted from the game without user paying gas
    function multisigMint(address minter, address to, uint256 amount, uint256 deadline, bytes32 _depositHash, bytes memory signatures) external whenNotPaused returns(bool) {
        require(deadline >= block.timestamp, "MINT_DEADLINE_EXPIRED");
        require(requiredSigs >= MIN_SIGS, "REQUIRED_SIGS_TOO_LOW");
        bytes32 dataHash;
        dataHash =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "multisigMint(address minter,address to,uint256 amount,uint256 nonce,uint256 deadline,bytes signatures)"
                            ),
                            minter,
                            to,
                            amount,
                            nonces[minter]++,
                            deadline
                        )
                    )
                )
            );
        checkNSignatures(minter, dataHash, requiredSigs, signatures);
        _mint(to, amount);
        emit Withdrawal(to, amount, _depositHash);
        return true;
    }

}
