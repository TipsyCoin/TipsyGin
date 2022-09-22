from web3 import Web3
from web3.auto import w3
from eth_abi import encode_abi

EIPMINT_METHOD_STRING = "eipMint(address minter,address to,uint256 amount,uint256 nonce,uint256 deadline)"
MULTISIG_METHOD_STRING = "multisigMint(address minter,address to,uint256 amount,uint256 nonce,uint256 deadline,bytes signatures)"
#Priv keys are well known, and only for testing and proof of concept
#For full bridge release, we'll have 1 server with pk get consensus from a different server with different pk
#So don't worry about it
MULTISIG_PRIVKEY_01 = "0000000000000000000000000000000000000000000000000000000000000001"
MULTISIG_PRIVKEY_02 = "0000000000000000000000000000000000000000000000000000000000000002"
MULTISIG_PUBKEY_01 = Web3.toChecksumAddress("0x7e5f4552091a69125d5dfcb7b8c2659029395bdf")
MULTISIG_PUBKEY_02 = Web3.toChecksumAddress("0x2b5ad5c4795c026514f8317c7a215e218dccd6cf")
GIN_TOKEN_ADDRESS = "0xe0bD6D04ea028F46D5392eBd33d73fd715Bcc778"
EIP712DOMAIN = "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
EIP712DOMAIN_KECCAK = w3.keccak(text=EIP712DOMAIN)
TOKEN_NAME_KECCAK = w3.keccak(text="Gin")
#KECCAK_1 is used for 'version'
KECCAK_1 = w3.keccak(text="1")
CHAIN_ID = 5
minter = ""
to = ""
nonce = 0
amount = int(1e18)
deadline = int(2**256-1)
presign = "\x19\x01"
METHOD_SELECTOR_EIPMINT = w3.keccak(text="eipMint(address,address,uint256,uint256,uint8,bytes32,bytes32)")[:4]
METHOD_SELECTOR_EIPMINT = w3.toHex(METHOD_SELECTOR_EIPMINT)
METHOD_SELECTOR_MULTIMINT = w3.keccak(text="multisigMint(address,address,uint256,uint256,bytes)")[:4]
METHOD_SELECTOR_MULTIMINT = w3.toHex(METHOD_SELECTOR_MULTIMINT)


def innerEncode(methodstring, minter, to, amount, nonce, deadline):
    assert(w3.isChecksumAddress(minter))
    assert(w3.isChecksumAddress(to))
    assert nonce == int(nonce) and 0 <= nonce < 2 ** 256
    assert deadline == int(deadline) and 0 <= deadline < 2 ** 256
    SelectorHash = w3.keccak(text=methodstring)
    msgHashInner1 = encode_abi(['bytes32', 'address', 'address', 'uint256', 'uint256', 'uint256'],
                                 [SelectorHash, minter, to, amount, nonce, deadline])
    msgHashInner1 = w3.keccak(msgHashInner1)
    return msgHashInner1


def DOMAIN_SEPERATOR(eip_address):
    assert len(TOKEN_NAME_KECCAK) == 32
    assert len(KECCAK_1) == 32
    assert w3.isChecksumAddress(eip_address)
    
    msgHashDomain = encode_abi(['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
                               [EIP712DOMAIN_KECCAK, TOKEN_NAME_KECCAK, KECCAK_1, CHAIN_ID, eip_address])
    msgHashDomain = w3.keccak(msgHashDomain)

    return msgHashDomain


if __name__ == '__main__':

    #You must hardcode the correct chain id and deployed gin token address for this test script to work
    #No complaining
    PRIV_KEY_ARRAY = [MULTISIG_PRIVKEY_01, MULTISIG_PRIVKEY_02]
    PUB_KEY_ARRAY = [MULTISIG_PUBKEY_01, MULTISIG_PUBKEY_02]
    CHAIN_ID = 1
    GIN_TOKEN_ADDRESS = "0x5A86858aA3b595FD6663c2296741eF4cd8BC4d01"
    methodText = MULTISIG_METHOD_STRING #EIPMINT_METHOD_STRING
    functionSelector = METHOD_SELECTOR_MULTIMINT #METHOD_SELECTOR_EIPMINT
    minter = MULTISIG_PUBKEY_01
    to = MULTISIG_PUBKEY_02
    nonce = 0

    #innerhash calcs fine without chain_id and token address
    msgHashInner = innerEncode(methodText, minter, to, amount, nonce, deadline)
    msgHashInnerText = w3.toHex(msgHashInner)

    msgHashDomain = DOMAIN_SEPERATOR(GIN_TOKEN_ADDRESS)
    msgHashDomainText = w3.toHex(msgHashDomain)

    print(f"InnerHash= {msgHashInnerText}")
    print(f"Domain Seperator= {msgHashDomainText}")

    #outerhash does NOT calculate properly without chain_id and gin token address set
    #chain_id is 1 for remix javascript node
    msgHashOuter = w3.solidityKeccak(['string', 'bytes32', 'bytes32'], [presign, msgHashDomain, msgHashInner])
    msgHashOuter = w3.toHex(msgHashOuter)
    print(f"OuterHash= {msgHashOuter}")

    print(f"minter: {minter}")
    print(f"to: {to}")
    print(f"amount: {amount}")
    print(f"deadline: {deadline}")
    sigsListGood = bytes(0)
    for i in range (1,-1, -1):
        print(f"For account: {PUB_KEY_ARRAY[i]}")
        signedMessage = w3.eth.account.signHash(msgHashOuter, PRIV_KEY_ARRAY[i])
        print(f'v: {signedMessage.v}')
        rVal = signedMessage.r.to_bytes(32, byteorder='big')
        print(f'r: {Web3.toHex(rVal)}')
        sVal = signedMessage.s.to_bytes(32, byteorder='big')
        print(f's: {Web3.toHex(sVal)}')
        vVal = signedMessage.v.to_bytes(1, byteorder='big')

        sigsListGood += rVal
        sigsListGood += sVal
        sigsListGood += vVal
        print(f'Encoded Sigs (USE THIS): {w3.toHex(sigsListGood)}')

    transactionData = encode_abi(['address', 'address', 'uint256', 'uint256', 'bytes'],
               [minter, to, amount, deadline, sigsListGood])
    transactionDataText = w3.toHex(transactionData)
    transactionDataText = METHOD_SELECTOR_MULTIMINT + transactionDataText[2:]
    print(f'Full TX data: {transactionDataText}')

    print("FINISHED")
