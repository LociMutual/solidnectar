#!/usr/bin/python3

from brownie import EmissionCurves, accounts, chain

def main():
    assert chain.id == 1 # mainnet

    deployer = accounts.load('loci_admin')

    EmissionCurves.deploy({'gas_price': 32_000_000_000, 'from': deployer}, publish_source=True)
