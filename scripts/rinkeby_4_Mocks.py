#!/usr/bin/python3

from brownie import accounts, chain, MockERC20

def main():
    assert chain.id == 4 # rinkeby

    deployer = accounts.load('core_account')
    sig = {'from': deployer}

    USDC = MockERC20.deploy('Fake USDC', 'USDC', sig)
    USDT = MockERC20.deploy('Fake USDT', 'USDC', sig)
    DAI  = MockERC20.deploy('Fake DAI', 'DAI', sig)

    MockERC20.publish_source(USDC)
    MockERC20.publish_source(USDT)
    MockERC20.publish_source(DAI)
