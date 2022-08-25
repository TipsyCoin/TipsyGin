// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;
import "./gin_eip_abstract.sol";
import "./OwnableKeepable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
//import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Gin is GinTest, Ownable, Pausable, Initializable
{

constructor() GinTest("GIN","$gin",18) {

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

function initialize() public initializer
{
    require(false, "Not yet");
}

function chainId() public view returns (uint)
{
    return block.chainid;
}

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

function addContract(address _newSigner) public onlyOwner returns (bool)
{
    return addContractMinter(_newSigner);
}

function addSigner(address _newSigner) public onlyOwner returns (bool)
{
    return addContractMinter(_newSigner);
}



//Staking contract only mint function
function mintTo(address _to, uint256 _amount) public returns (bool)
{
    require(contractMinters[msg.sender] == true, "mintTo only for contract minters. Use EIPMint for EOA.");
    _mint(_to, _amount);
    emit Mint(msg.sender, _to, _amount);
    return true; //return bool required for our staking contract to function
}

function deposit(address _from, uint256 _amount) public returns (bool)
{
    require(transferFrom(_from, address(this), _amount), "Deposit failed. You must approve first");
    _burn(address(this), _amount);
    emit Deposit(_from, _amount);
    return true;
}

//Manual testing to ensure Python server is doing things exactly the same way
//Much sadness has been had because of the different encoding of abi.encode and abi.encodePacked
//abi.encode should be used to avoid tx malleability attacks, though
//e.g. the keccak256 using encodePacked for nonce 1 and deadline 123 might be identical to nonce 11 and deadline 23. This is obviously bad.
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
