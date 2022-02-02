#!/usr/bin/python3

from brownie import Auction, LG, LGX, accounts

def main():
    # If these addresses do not exist then in lib/1155-to-20 run:
    #   npx truffle migrate --network rinkeby
    singletonFactory = '0xce0042B868300000d44A59004Da54A005ffdcf9f'
    wrapped1155Factory = '0xdBaB2d2F2b8e74CDeFCbD0fBeC138177E65AE9e5'

    governor = '0x24cAc427c956a086bd975Aa718f0B271e7778FEf'
    deployer = accounts.load('core_account')
    lg = LG[-1]
    auction = Auction[-1]

    sig = {
        'from': deployer
    }

    LGX.deploy(governor, 111, sig, publish_source=True)