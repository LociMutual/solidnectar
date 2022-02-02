#!/usr/bin/python3

from brownie import Auction, LG, accounts

def main():
    # If these addresses do not exist then in lib/1155-to-20 run:
    #   npx truffle migrate --network rinkeby
    singletonFactory = '0xce0042B868300000d44A59004Da54A005ffdcf9f'
    wrapped1155Factory = '0xdBaB2d2F2b8e74CDeFCbD0fBeC138177E65AE9e5'

    governor = '0x24cAc427c956a086bd975Aa718f0B271e7778FEf'
    deployer = accounts.load('core_account')

    sig = {
        'from': deployer
    }

    lg = LG.deploy(governor, "ipfs://QmboBADQ1G8gRe42fQzXoLeYvNj2D78xfB2nwx4swkyYf2/{id}.json", sig, publish_source=True)
    auction = Auction.deploy(governor, lg, lg.AUCTION22_ALLOCATION(), 900, governor, sig, publish_source=True)
    lg.grantRole(lg.AUCTION22_ALLOCATION(), auction)