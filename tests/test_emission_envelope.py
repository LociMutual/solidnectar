from brownie import chain, reverts


def test_change(admin, adminSig, governorSig, lg):
    AUCTION = lg.ANON_ALLOCATION()
    lg.grantRole(AUCTION, admin, governorSig)
    lg.setCurve(AUCTION, chain.time(),
         900, 30,  # 15 minutes of cubic ramp-up
        1800,      # 30 minutes of max emissions
        3600, 30,  # 60 minutes of cubic decay
        governorSig)
    chain.sleep(60)
    chain.mine()
    available = lg.allocationAvailable(AUCTION)                                 

    lg.allocationMint(admin, AUCTION, 1e18, adminSig)
    available = lg.allocationAvailable(AUCTION)                                 

    # cannot change allocation to something less than what was alredy minted
    with reverts():
        lg.allocationAllocate(AUCTION, 0, 1e17, governorSig)

    # lower allocation units to exactly what was minted
    lg.allocationAllocate(AUCTION, 0, 1e18, governorSig)
    available = lg.allocationAvailable(AUCTION)
    assert available == 0
    
    # cannot mint 1 wei more than the altered allocation
    with reverts():
        lg.allocationMint(admin, AUCTION, 1, adminSig)


def test_curve(admin, adminSig, governorSig, lg):
    AUCTION = lg.ANON_ALLOCATION()
    lg.setCurve(AUCTION, chain.time(),
            1800, 4,  # 1/2 hour ramp-up
            3600,     # 1 hour of max emissions
           10800, 1,  # 3 hours of decay
        governorSig)

    lg.grantRole(AUCTION, admin, governorSig)

    with reverts():
        lg.allocationMint(admin, AUCTION, 1e28, adminSig)

    chain.sleep(3600)
    # there should be at least a few hundred ready to mint
    lg.allocationMint(admin, AUCTION, 1e18, adminSig)
    assert lg.balanceOf(admin) == 1e18


def test_recm_growth(lg):
    AUCTION = lg.RECM_ALLOCATION()
    n = 0
    while True:
        assert n <= 5 * 52 # 5 years of weeks

        n += 1
        available = lg.allocationAvailable(AUCTION)
        print(available/1e18)
        if available == lg.allocationSlice(AUCTION)['units']:
            break
        chain.sleep(7 * 86400)
        chain.mine()


def test_growth(lg):
    AUCTION = lg.ANON_ALLOCATION()
    n = 0
    while True:
        assert n <= 26 + 4 * 52 # weeks

        n += 1
        available = lg.allocationAvailable(AUCTION)
        print(available/1e18)
        if available == lg.allocationSlice(AUCTION)['units']:
            break
        chain.sleep(7 * 86400)
        chain.mine()
