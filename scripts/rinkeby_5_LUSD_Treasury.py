#!/usr/bin/python3

from brownie import accounts, chain, Contract, LUSD, LX_Treasury, MockERC20, web3
import json

def main():
    assert chain.id == 4 # rinkeby

    multisig = '0x167975F759e9fC3C5f176Aa7648Bc89FD510c410'
    
    # rinkeby WETH9
    WETH9 = '0xc778417E063141139Fce010982780140Aa0cD5Ab'

    deployer = accounts.load('core_account')
    sig = {'from': deployer}

    USDC = MockERC20[-3]
    USDT = MockERC20[-2]
    DAI  = MockERC20[-1]

    treasury = LX_Treasury.deploy(
        multisig,
        [USDC.address, USDT.address, DAI.address],
        [5000, 3000, 2000], # reserve targets
        [9500, 9700],       # minmax reserves
        [ 111,  300],       #        origination fee
        [   0,  111],       #        redemption fee
        WETH9,
        sig)

    LX_Treasury.publish_source(treasury)
