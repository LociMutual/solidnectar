#!/usr/bin/python3

from brownie import Auction, LG, accounts, chain

def main():
    assert chain.id == 1 # mainnet

    multisig = '0x1EDFA2b0D7086A04bBcFF300c9BE8a50308e23f9'

    deployer = accounts.load('loci_admin')

    LG.deploy(multisig, {'gas_price': 20_000_000_000, 'from': deployer})
