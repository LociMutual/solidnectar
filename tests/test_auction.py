from brownie import chain, reverts

def test_auction(admin, auction, lg):
    admin.transfer(auction, 1e18)
    chain.sleep(900)
    auction.claim()
    assert lg.balanceOf(admin) == auction.auctionSupply(1)

def test_auction_no_early_claim(admin, auction, lg):
    admin.transfer(auction, 1e18)
    chain.sleep(500)
    auction.claim()
    assert lg.balanceOf(admin) == 0

def test_auction_split(admin, accounts, auction, lg):
    admin.transfer(auction, 1e18)
    accounts[1].transfer(auction, 1e18)
    chain.sleep(900)
    auction.claim()
    auction.claim({'from':accounts[1]})
    assert lg.balanceOf(admin) == auction.auctionSupply(1) // 2

def test_auction_redundant(admin, auction, lg):
    admin.transfer(auction, 1e18)
    chain.sleep(900)
    auction.claim()
    assert lg.balanceOf(admin) == auction.auctionSupply(1)
    auction.claim()
    assert lg.balanceOf(admin) == auction.auctionSupply(1)
