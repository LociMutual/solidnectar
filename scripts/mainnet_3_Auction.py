#!/usr/bin/python3

from brownie import Auction, LG, accounts, chain

def main():
    assert chain.id == 1 # mainnet

    multisig = '0x1EDFA2b0D7086A04bBcFF300c9BE8a50308e23f9'

    deployer = accounts.load('loci_admin')

    lg = LG[-1]
    auction = Auction.deploy(multisig, lg, lg.ANON_ALLOCATION(), 7 * 86400,  {'gas_price': 40_000_000_000, 'from': deployer})
    lg.grantRole(lg.ANON_ALLOCATION(), auction, {'gas_price': 40_000_000_000, 'from': deployer})
    
    Auction.publish_source(auction)
