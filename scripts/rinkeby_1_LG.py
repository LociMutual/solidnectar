#!/usr/bin/python3

from brownie import Contract, LG, accounts, chain, web3
import json

ISingletonFactory = json.load(open("./build/interfaces/ISingletonFactory.json"))['abi']

SINGLETON_FACTORY_ADDRESS = '0xce0042B868300000d44A59004Da54A005ffdcf9f'

def main():
    assert chain.id == 4 # rinkeby

    multisig = '0x167975F759e9fC3C5f176Aa7648Bc89FD510c410'

    deployer = accounts.load('core_account')
    sig = {'from': deployer}

    LG.deploy(multisig, sig, publish_source=True)
