from brownie import accounts, chain, reverts, web3

def test_lx_receive_eth(admin, lx):
    print(chain.id)
    print()
    admin.transfer(lx, 1e11)

def test_lx_originate_eth(admin, lx):
    lx.originate(admin, 1e14, chain.time + 60, {'from': admin, 'value': 1e11})

def test_lx_originate_usdc(admin, adminSig, USDC, lx):
    USDC.mint(admin, 1e19, adminSig)
    with reverts():
        lx.originate(admin, USDC, 1e11, adminSig)

    USDC.approve(lx, 1e18, adminSig)
    lx.originate(admin, USDC, 1e11, adminSig)

def test_lx_originate_usdc_permit(admin, adminSig, USDC, lx):
    #signed = web3.eth.sign ... abi.encodePacked('Permit(address,address,uit256)', admin, admin, 1e18)
    lx.originate(admin, admin, USDC, 1e11, chain.time + 60, signed.v, signed.r, signed.s, adminSig)
