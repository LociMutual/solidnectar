from brownie import ZERO_ADDRESS, chain, reverts, web3

def test_vote(accounts, admin, adminSig, governorSig, lg):
    lg.grantRole(lg.RESERVE_ALLOCATION(), admin, governorSig)

    lg.allocationMint(admin, lg.RESERVE_ALLOCATION(), 1e18, adminSig)
    print(lg.balanceOf(admin)/1e18, lg.votingPower(0, lg.balanceOf(admin)), lg.getVotes(admin), lg.numCheckpoints(admin))

    lg.delegate(admin, adminSig)
    print(lg.balanceOf(admin)/1e18, lg.votingPower(0, lg.balanceOf(admin)), lg.getVotes(admin), lg.numCheckpoints(admin))

    lg.allocationMint(admin, lg.RESERVE_ALLOCATION(), 5000e18, adminSig)
    print(lg.balanceOf(admin)/1e18, lg.votingPower(0, lg.balanceOf(admin)), lg.getVotes(admin), lg.numCheckpoints(admin))

    lg.allocationMint(admin, lg.RESERVE_ALLOCATION(), 3000e18, adminSig)
    print(lg.balanceOf(admin)/1e18, lg.votingPower(0, lg.balanceOf(admin)), lg.getVotes(admin), lg.numCheckpoints(admin))

    lg.delegate(admin, adminSig)
    print(lg.balanceOf(admin)/1e18, lg.votingPower(0, lg.balanceOf(admin)), lg.getVotes(admin), lg.numCheckpoints(admin))

    lg.transfer(accounts[1], 7000e18, adminSig)
    print(lg.balanceOf(admin)/1e18, lg.votingPower(0, lg.balanceOf(admin)), lg.getVotes(admin), lg.numCheckpoints(admin))

    lg.transfer(admin, 7000e18, {'from': accounts[1]})    
    print(lg.balanceOf(admin)/1e18, lg.votingPower(0, lg.balanceOf(admin)), lg.getVotes(admin), lg.numCheckpoints(admin))

    lg.delegate(ZERO_ADDRESS, adminSig)
    print(lg.balanceOf(admin)/1e18, lg.votingPower(0, lg.balanceOf(admin)), lg.getVotes(admin), lg.numCheckpoints(admin))

    lg.delegate(admin, adminSig)
    print(lg.balanceOf(admin)/1e18, lg.votingPower(0, lg.balanceOf(admin)), lg.getVotes(admin), lg.numCheckpoints(admin))

