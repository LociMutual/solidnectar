#!/usr/bin/python3

from brownie import Auction, LG, accounts, chain

def main():
    assert chain.id == 4 # rinkeby

    multisig = '0x167975F759e9fC3C5f176Aa7648Bc89FD510c410'

    deployer = accounts.load('core_account')
    sig = {'from': deployer}

    lg = LG[-1]
    lg.setCurve(lg.ANON_ALLOCATION(), chain.time(),
            86400, 30,  # 1 day ramp-up
            86400,      # 1 day max emissions
        3 * 86400, 20,  # 3 days of decay
        sig)

    auction = Auction.deploy(multisig, lg, lg.ANON_ALLOCATION(), 3600, sig)
    lg.grantRole(lg.ANON_ALLOCATION(), auction, sig)
    
    Auction.publish_source(auction)
