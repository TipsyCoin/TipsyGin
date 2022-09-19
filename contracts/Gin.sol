// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;
import "./Solmate_modified.sol";
import "./OwnableKeepable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
//import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Gin is GinTest, Ownable, Pausable, Initializable
{

/*constructor() GinTest("GIN","$gin",18) {

address _keeper = msg.sender;
address owner_ = msg.sender;
require(_keeper != address(0), "Tipsy: keeper can't be 0 address");
require(owner_ != address(0), "Tipsy: owner can't be 0 address");

keeper = _keeper;
initOwnership(owner_);
addMintSigner(address(0x7f6BD150cd11593aE6C31A5F43A3fB7887A18C63));

//Add BSC Tipsy staking contract here
//addContractMinter(address(0));
}
*/

//Testing Only
function _testInit() public
{
    initialize(msg.sender, msg.sender);
    permitSigner(address(0x7f6BD150cd11593aE6C31A5F43A3fB7887A18C63));
    permitSigner(address(msg.sender));
}

//Test initialize function only
function initialize(address owner_, address _keeper) public initializer
{
        require(decimals == 18, "Static Var check");
        require(_keeper != address(0), "Tipsy: keeper can't be 0 address");
        require(owner_ != address(0), "Tipsy: owner can't be 0 address");
        keeper = _keeper;
        initOwnership(owner_);

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();


}

function chainId() public view returns (uint)
{
    return block.chainid;
}

function return_max() public pure returns (uint256)
{
    return ~uint256(0);
}

//Testing Only
function _keccakInner() public pure returns (bytes32)
{
    address minter = address(0x7f6BD150cd11593aE6C31A5F43A3fB7887A18C63);
    address to = address(0xF052482E025a056146d903a8802d04e7328543F5);
    uint256 amount = 1e18;
    uint256 nonce = 0;
    uint256 deadline = ~uint256(0);

    bytes32 returnVal =     keccak256(
                            abi.encode(
                                keccak256(
                                    "eipMint(address minter,address to,uint256 amount,uint256 nonce,uint256 deadline)"
                                ),
                                minter,
                                to,
                                amount,
                                nonce,
                                deadline
                            )
                        );
    return returnVal;
}
//Testing Only
function _keccakCheckak() public view returns (bytes32)
{
    address minter = address(0x7f6BD150cd11593aE6C31A5F43A3fB7887A18C63);
    address to = address(0xF052482E025a056146d903a8802d04e7328543F5);
    uint256 amount = 1e18;
    uint256 deadline = ~uint256(0);

    bytes32 returnVal =
    keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "eipMint(address minter,address to,uint256 amount,uint256 nonce,uint256 deadline)"
                                ),
                                minter,
                                to,
                                amount,
                                nonces[to],
                                deadline
                            )
                        )
                    ));

return returnVal;

}

function permitContract(address _newSigner) public onlyOwner returns (bool)
{
    return _addContractMinter(_newSigner);
}

function permitSigner(address _newSigner) public onlyOwner returns (bool)
{
    return _addContractMinter(_newSigner);
}

function revokeSigner(address _newSigner) public onlyOwnerOrKeeper returns (bool)
{
    return _removeMintSigner(_newSigner);
}

function revokeContract(address _newSigner) public onlyOwnerOrKeeper returns (bool)
{
    return _removeContractMinter(_newSigner);
}

function setRequiredSigs(uint8 _numberSigs) public onlyOwner returns (uint8)
{
    require(_numberSigs >= MIN_SIGS, "SIGS_BELOW_MINIMUM");
    requiredSigs = _numberSigs;
    return _numberSigs;
}

//Standard emergency stop button
function setPause(bool _paused) public onlyOwnerOrKeeper
{
    if (_paused == true)
    {
        _pause();
    }
    else
    {
        _unpause();
    }
}
//Test function, remove before launch.
function testMint(address _to, uint256 _amount) public whenNotPaused returns (bool)
{
    _mint(_to, _amount);
    emit Mint(msg.sender, _to, _amount);
    return true; //return bool required for our staking contract to function
}

//Staking contract only mint function
function mintTo(address _to, uint256 _amount) public whenNotPaused returns (bool)
{
    require(contractMinters[msg.sender] == true, "mintTo only for contract minters. Use EIPMint for EOA.");
    _mint(_to, _amount);
    emit Mint(msg.sender, _to, _amount);
    return true; //return bool required for our staking contract to function
}

//Deposit from the 
function deposit(address _from, uint256 _amount) public whenNotPaused returns (bool)
{
    require(transferFrom(_from, address(this), _amount), "Deposit failed. You must approve this contract first");
    _burn(address(this), _amount);
    emit Deposit(_from, _amount);
    return true;
}

//MultiSig Mint. Used so server can sign message offchain and send via relay network to required chain contract
function multisigMint(address minter, address to, uint256 amount, uint256 deadline, bytes memory signatures) public virtual {
        require(deadline >= block.timestamp, "MINT_DEADLINE_EXPIRED");
        bytes32 dataHash;
        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
            dataHash =
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "multisigMint(address minter,address to,uint256 amount,uint256 nonce,uint256 deadline)"
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
        checkNSignatures(minter, dataHash, signatures);
        _mint(to, amount);
        emit Withdrawal(to, amount);
    }

//Manual testing to ensure Python server is doing things exactly the same way
//Much sadness has been had because of the different encoding of abi.encode and abi.encodePacked
//abi.encode should be used to avoid tx malleability attacks, though
//e.g. the keccak256 using encodePacked for nonce 1 and deadline 123 might be similiar to nonce 11 and deadline 23. This is obviously bad.
function _verifyEIPMint(address minter,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s) public view returns (address)
{
        require(deadline >= block.timestamp, "Tipsy: Mint Deadline Expired");
        require(mintSigners[minter] == true, "Tipsy: Not Authorized to Mint");
        require(contractMinters[minter] == false, "Tipsy: Contract use mintTo instead");
        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "eipMint(address minter,address to,uint256 amount,uint256 nonce,uint256 deadline)"
                                ),
                                minter,
                                to,
                                amount,
                                nonces[to],
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );
            return recoveredAddress;
    }
}