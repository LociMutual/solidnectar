from brownie import chain, reverts, web3

def test_mint_requires_role(admin, adminSig, lg):
    with reverts():
        lg.allocationMint(admin, lg.RESERVE_ALLOCATION(), 1e18, adminSig)

def test_mint_with_role(admin, adminSig, governorSig, lg):
    lg.grantRole(lg.RESERVE_ALLOCATION(), admin, governorSig)
    lg.allocationMint(admin, lg.RESERVE_ALLOCATION(), 1e18, adminSig)
    assert lg.balanceOf(admin) == 1e18

def test_new_allocation(admin, adminSig, governorSig, lg):
    NEW_ALLOCATION_ROLE = web3.keccak(text='NEW_ALLOCATION_ROLE')
    lg.allocationAllocate(NEW_ALLOCATION_ROLE, 1, 1_000_000 * 1e18, governorSig)
    lg.grantRole(NEW_ALLOCATION_ROLE, admin, governorSig)
    lg.allocationMint(admin, NEW_ALLOCATION_ROLE, 5e17, adminSig)
    assert lg.balanceOf(admin) == 5e17
    assert lg.allocationTotalSupplyCap()       == 442_000_000 * 1e18
    assert lg.allocationSupplyCapPerTokenId(0) == 440_650_000 * 1e18
    assert lg.allocationSupplyCapPerTokenId(1) ==   1_350_000 * 1e18
