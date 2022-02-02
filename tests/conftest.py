#!/usr/bin/python3

import pytest
from brownie import accounts, chain

@pytest.fixture(scope="function", autouse=True)
def isolate(fn_isolation):
    # perform a chain rewind after completing each test, to ensure proper isolation
    # https://eth-brownie.readthedocs.io/en/v1.10.3/tests-pytest-intro.html#isolation-fixtures
    pass

@pytest.fixture(scope="module")
def admin():
    return accounts[0]

@pytest.fixture(scope="module")
def adminSig():
    return {'from': accounts[0]}

@pytest.fixture(scope="module")
def governor():
    return accounts[9]

@pytest.fixture(scope="module")
def governorSig():
    return {'from': accounts[9]}

@pytest.fixture(scope="module")
def treasury():
    return accounts[8]

@pytest.fixture(scope="module")
def lg(adminSig, LG, governor):
    return LG.deploy(governor, "ipfs://QmboBADQ1G8gRe42fQzXoLeYvNj2D78xfB2nwx4swkyYf2/{id}.json", adminSig)

@pytest.fixture(scope="module")
def auction(adminSig, governor, treasury, lg, Auction):
    a = Auction.deploy(governor, lg, lg.AUCTION22_ALLOCATION(), 900, treasury, adminSig)
    lg.grantRole(lg.AUCTION22_ALLOCATION(), a)
    return a

def approx(a, b, precision=1e-15):
    if a == b == 0:
        return True
    return 2 * abs(a - b) / (a + b) <= precision
