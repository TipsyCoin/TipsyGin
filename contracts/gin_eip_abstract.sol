// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Gin (https://github.com/TipsyCoin/TipsyGin/), modified from Solmate
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract GinTest {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    event Mint(address indexed minter, address indexed to, uint256 amount);
    event Burn(address indexed burner, address indexed from, uint256 amount);

    event Deposit(address indexed from, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);
    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => bool) public mintSigners;

    mapping(address => bool) public contractMinters;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal INITIAL_CHAIN_ID;
    //These can't be immutable in upgradeable proxy
    bytes32 public INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    //Change to initialize for upgrade purposes.
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                             MATSUKO-DELUXE LOGIC
    //////////////////////////////////////////////////////////////*/
    function addContractMinter(address _newSigner) internal virtual returns (bool)
    {
        //require (msg.sender == address(this), "Only internal calls, please"); 
        uint size;
        assembly {
            size := extcodesize(_newSigner)
        }
        require(size > 0, "Direct Signer must be a contract");
        contractMinters[_newSigner] = true;
        return true;
    }

    function removeContractMinter(address _removedSigner) internal virtual returns (bool)
    {
        //require (msg.sender == address(this), "Only internal calls, please"); 
        uint size;
        assembly {
            size := extcodesize(_removedSigner)
        }
        require(size > 0, "Direct Signer must be a contract");
        contractMinters[_removedSigner] = true;
        return true;
    }

        function addMintSigner(address _newSigner) internal virtual returns (bool)
    {
        //require (msg.sender == address(this), "Only internal calls, please"); 
        uint size;
        assembly {
            size := extcodesize(_newSigner)
        }
        require(size == 0, "Direct Signer should be EOA");
        mintSigners[_newSigner] = true;
        return true;
    }

    function removeMintSigner(address _removedSigner) internal virtual returns (bool)
    {
        //require (msg.sender == address(this), "Only internal calls, please"); 
        uint size;
        assembly {
            size := extcodesize(_removedSigner)
        }
        require(size == 0, "Direct Signer should be EOA");
        mintSigners[_removedSigner] = true;
        return true;
    }



    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    function eipMint(
        address minter,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "MINT_DEADLINE_EXPIRED");
        require(mintSigners[minter] == true, "NOT_AUTHORIZED_TO_MINT");
        require(contractMinters[minter] == false, "USE_CONTRACT_MINT_INSTEAD");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
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
                                nonces[minter]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == minter, "INVALID_SIGNER");

        }

        _mint(to, amount);
        emit Withdrawal(to, amount);

    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() public view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    /*function mintTo(
        address _to,
        uint _amount
    ) internal virtual returns (bool)
    {
        require(_to != address(0), 'ERC20: to address is not valid');
        require(_amount > 0, 'ERC20: amount is not valid');

        totalSupply = totalSupply + _amount;
        balanceOf[_to] = balanceOf[_to] + _amount;

        emit Mint(msg.sender, _to, _amount);
        return true;
    }

    function burnFrom(
        address _from,
        uint _amount
    ) internal virtual
    {
        require(_from != address(0), 'ERC20: from address is not valid');
        require(balanceOf[_from] >= _amount, 'ERC20: insufficient balance');
        
        balanceOf[_from] = balanceOf[_from] - _amount;
        totalSupply = totalSupply - _amount;

        emit Burn(msg.sender, _from, _amount);
    }*/

}
