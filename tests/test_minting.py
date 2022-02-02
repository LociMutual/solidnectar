from brownie import chain, reverts
from web3 import Web3
import pytest

def test_mint_requires_role(admin, adminSig, lg):
    with reverts():
        lg.allocationMint(admin, lg.RESERVED_ALLOCATION(), 1e18, adminSig)

def test_mint_with_role(admin, adminSig, governorSig, lg):
    lg.grantRole(lg.RESERVED_ALLOCATION(), admin, governorSig)
    lg.allocationMint(admin, lg.RESERVED_ALLOCATION(), 1e18, adminSig)
    assert lg.balanceOf(admin) == 1e18
