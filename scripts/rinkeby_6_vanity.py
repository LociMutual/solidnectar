from binascii import hexlify
from brownie import LG, web3

def singleton_address(deployer, salt, bytecode):
    return web3.solidityKeccak(
        ('bytes', 'address', 'bytes32', 'bytes32'),
        ('0xff', deployer, salt, web3.keccak(hexstr=bytecode)))[12:]

def hexpad(s, n):
    return '0x' + s[2:].zfill(n)

multisig = '0x167975F759e9fC3C5f176Aa7648Bc89FD510c410'
initCode = LG.bytecode + web3.eth.codec.encode_single('address', multisig).hex()
print(initCode)
n = 0
while True:
    salt = hexpad(hex(n), 64)
    addr = singleton_address('0xce0042B868300000d44A59004Da54A005ffdcf9f', salt, initCode)
    if addr.hex().startswith('0x111'):
        print(salt, web3.toChecksumAddress(addr))
    n += 1
