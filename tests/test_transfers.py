from brownie import chain, reverts
from web3 import Web3
import pytest

def test_transfer(admin, accounts, adminSig, governorSig, lg):
    RESERVE = lg.RESERVED_ALLOCATION()
    lg.grantRole(RESERVE, admin, governorSig)
    lg.allocationMint(admin, RESERVE, 10e18, adminSig)
    lg.transfer(accounts[1], 2e18, adminSig)
    assert lg.balanceOf(admin) == 8e18
    assert lg.balanceOf(accounts[1]) == 2e18
    lg.transfer(admin, 1e18, {'from': accounts[1]})
    assert lg.balanceOf(admin) == 9e18
    assert lg.balanceOf(accounts[1]) == 1e18
