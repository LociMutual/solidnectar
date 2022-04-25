#!/usr/bin/python3

from brownie import accounts, chain, Contract, LUSD, LX_Treasury, web3
import json

ISingletonFactory = json.load(open("./build/interfaces/ISingletonFactory.json"))['abi']

def main():
    assert chain.id == 4 # rinkeby

    deployer = accounts.load('core_account')

    treasury = '0xA31e33DB32212F6160cbc464f306A6D14b8d9c4E'
    initCode = LUSD.bytecode + web3.eth.codec.encode_single('address', treasury).hex()
    salt = '0x0000000000000000000000000000000000000000000000000000000000038d9e'
    deterministicLUSD = '0x111DCEDb416DeDF58970081B293b8BE67694ac9D'

    factory = Contract.from_abi('SingletonFactory', '0xce0042B868300000d44A59004Da54A005ffdcf9f', ISingletonFactory)
    factory.deploy(initCode, salt, {'from': deployer, 'gas_limit': 2000000})
    LX_Treasury.at(treasury).initialize(deterministicLUSD, {'from': deployer})

    LUSD.publish_source(LUSD.at(deterministicLUSD))
