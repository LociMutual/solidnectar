#!/usr/bin/python3

import pytest
from brownie import accounts, chain, Contract, project

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
def lg(adminSig, LG, governor, EmissionCurves):
    EmissionCurves.deploy(adminSig)
    return LG.deploy(governor, adminSig)

@pytest.fixture(scope="module")
def auction(adminSig, governor, lg, Auction, governorSig):
    a = Auction.deploy(governor, lg, lg.ANON_ALLOCATION(), 900, adminSig)
    lg.grantRole(lg.ANON_ALLOCATION(), a, governorSig)
    return a

@pytest.fixture(scope="module")
def USDC(admin, MockERC20, adminSig):
    t = MockERC20.deploy('Fake USDC', 'USDC', adminSig)
    addLiquidity(t, 2800e18, admin, 1e15)
    return t

@pytest.fixture(scope="module")
def USDT(MockERC20, adminSig):
    return MockERC20.deploy('Fake USDT', 'USDT', adminSig)

@pytest.fixture(scope="module")
def DAI(MockERC20, adminSig):
    return MockERC20.deploy('Fake DAI', 'DAI', adminSig)

@pytest.fixture(scope="module")
def lx(admin, adminSig, LX_Treasury, USDC, USDT, DAI):
    return LX_Treasury.deploy(
        admin,
        'Loci USD',
        'LUSD',
        [USDC, USDT, DAI],
        [5000, 3000, 2000], # reserve targets
        [95, 97],           # minmax reserves
        [0, 0],             #        pooled
        [111, 300],         #        origination fee
        [  0, 111],         #        redemption fee
        111,                # flash loan fee
        adminSig)

def approx(a, b, precision=1e-15):
    if a == b == 0:
        return True
    return 2 * abs(a - b) / (a + b) <= precision

def addLiquidity(token, price, account, value):
    amount = value * price / 1e18;
    token.mint(account, amount, {'from': account});

    WETH9 = project.SmartProject.interface.IERC20(token.WETH9())
    account.transfer(WETH9, value)
    assert WETH9.balanceOf(account) >= value

    positions = project.SmartProject.interface.INonfungiblePositionManager(token.positions())
    WETH9.approve(positions, value, {'from': account});

    positions.mint(list({
        'token0': token.WETH9(),
        'token1': token,
        'fee': token.poolFee(),
        'tickLower': -887272,
        'tickUpper':  887272,
        'amount0Desired': value,
        'amount1Desired': amount,
        'amount0Min': 0,
        'amount1Min': 0,
        'recipient': account,
        'deadline': chain.time() + 60
    }.values()),
    {'from': account})
