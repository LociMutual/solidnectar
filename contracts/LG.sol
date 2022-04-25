// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "./ERC20_1155Votes.sol";
import "./AllocationControl.sol";
import "./ABDKMath64x64.sol";
import "./EmissionCurves.sol";
import "../interfaces/IAllocationMinter.sol";

/**
 * LG DAO - Main Protocol Token
 *
 *    One Ring to rule them all,
 *    One Ring to find them,
 *    One Ring to bring them all
 *    and in the ledger bind them.”
 *  
 *     ― J.K.W. Blockchain
 *
 * LG token voting power governs property directors and their continuous reinvestment of
 * net cash flows in multi-industry development projects and associated fixed-growth 
 * Loci Bell (LB) tokens.
 *
 * LG's multi-class voting mechanism presents an ERC20 voting interface compatible with
 * popular on-chain governance while differentiating expert voting power from common equity.
 *
 * 35% of voting power is passively held by DAO Foundation directors with less than 3% of LG
 * (a.k.a. LGY).  The remaining 97% of LG controls 65% of voting power.
 * 
 */
contract LG is ERC20_1155Votes, AllocationControl, IAllocationMinter {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;
    using EmissionCurves for EmissionCurves.Curve;

    bytes32 public constant RESERVE_ALLOCATION   = keccak256("RESERVE_ALLOCATION");
    bytes32 public constant ANON_ALLOCATION      = keccak256("ANON_ALLOCATION");
    bytes32 public constant LEGACY_ALLOCATION    = keccak256("LEGACY_ALLOCATION");
    bytes32 public constant RECM_ALLOCATION      = keccak256("RECM_ALLOCATION");
    bytes32 public constant WEB3_ALLOCATION      = keccak256("WEB3_ALLOCATION");
    bytes32 public constant DAO_ALLOCATION       = keccak256("DAO_ALLOCATION");
    bytes32 public constant Y_DAO_ALLOCATION     = keccak256("Y_DAO_ALLOCATION");
    bytes32 public constant LP_ALLOCATION        = keccak256("LP_ALLOCATION");
    bytes32 public constant TEAM_ALLOCATION      = keccak256("TEAM_ALLOCATION");

    mapping(bytes32 => EmissionCurves.Curve) curves;

    constructor(address daoMultisig)
        ERC20_1155Votes("Loci Global", "LG", "ipfs://QmboBADQ1G8gRe42fQzXoLeYvNj2D78xfB2nwx4swkyYf2/{id}.json", 2)
    {
        _grantRole(ALLOCATOR_ROLE, daoMultisig);
        _grantRole(ALLOCATOR_ROLE, msg.sender);
        _grantRole(WEB3_ALLOCATION, msg.sender);

        // LG DAO Long Term Reserves

        _allocationAllocate(RESERVE_ALLOCATION, 0, 185_000_000 * 1e18); // not minted

        // Anon Contributors

        _allocationAllocate(   ANON_ALLOCATION, 0,  99_000_000 * 1e18); // Auction Emission

        // Legacy Contributors

        _allocationAllocate( LEGACY_ALLOCATION, 0,  51_500_000 * 1e18);

        // Gaurdians

        _allocationAllocate(   RECM_ALLOCATION, 0,  24_400_000 * 1e18);
        _allocationAllocate(   WEB3_ALLOCATION, 0,  15_100_000 * 1e18); // Core Technology
        _allocationAllocate(    DAO_ALLOCATION, 0,  11_650_000 * 1e18);
        _allocationAllocate(  Y_DAO_ALLOCATION, 1,     350_000 * 1e18); // 35% vote

        // Blockchain Launch

        _allocationAllocate(     LP_ALLOCATION, 0,  20_700_000 * 1e18); // LP Reward Emission
        _allocationAllocate(   TEAM_ALLOCATION, 0,  33_300_000 * 1e18); // Property, Operations, Agents

        // Theoretical caps if/when each allocation role mints 100%

        require(allocationTotalSupplyCap()        == 441_000_000 * 1e18); // 185M non-mintable
        require(allocationSupplyCapPerTokenId(0)  == 440_650_000 * 1e18);
        require(allocationSupplyCapPerTokenId(1)  ==     350_000 * 1e18);

        // Initial Emission Curves

        curves[ANON_ALLOCATION] = EmissionCurves.newCurve(
            block.timestamp,
                26 * 7 * 86400, 30,  // 6 months ramp-up e^3.0x
            1 * 52 * 7 * 86400,      // 1 year of max emissions
            3 * 52 * 7 * 86400, 30); // 3 years of decay e^-3.0x

        curves[RECM_ALLOCATION] = EmissionCurves.newCurve(
            block.timestamp,
            3 * 52 * 7 * 86400, 20, // 3 years of ramp-up e^2x
            2 * 52 * 7 * 86400,     // 2 years of max emissions
            0, 0);

        curves[WEB3_ALLOCATION] = EmissionCurves.newCurve(
            block.timestamp,
            3 * 52 * 7 * 86400, 20, // 3 years of ramp-up e^2x
            2 * 52 * 7 * 86400,     // 2 years of max emissions
            0, 0);

        curves[DAO_ALLOCATION] = EmissionCurves.newCurve(
            block.timestamp,
            3 * 52 * 7 * 86400, 20, // 3 years of ramp-up e^2x
            2 * 52 * 7 * 86400,     // 2 years of max emissions
            0, 0);
    }

    function setURI(string memory newURI) public {
        _setURI(newURI);
    }

    function setCurve(
        bytes32 role,
        uint256 timeStart,
        uint32 durationGrowth,
        uint8 expGrowth,
        uint32 durationMax,
        uint32 durationDecay,
        uint8 expDecay
    )
        public
        onlyRole(ALLOCATOR_ROLE)
    {
        curves[role] = EmissionCurves.newCurve(timeStart, durationGrowth, expGrowth, durationMax, durationDecay, expDecay);
    }

    function allocationAllocate(bytes32 role, uint256 id, uint256 units)
        public
        onlyRole(ALLOCATOR_ROLE)
    {
        require(id < 2, "invalid class");
        _allocationAllocate(role, id, units);
    }

    function votingPower(uint256 id, uint256 amount)
        public
        view
        override
        returns (uint256)
    {
        require(id < 2, "invalid class");

        // A straightforward proportional weighting would be
        //
        // return (id == 1 ? 35 : 65) * amount / allocationSupplyCapPerTokenId(id);
        //
        // To make things easier for the majority of holders, however,
        // token 0 voting power is fixed at 1:1 and token 1 is scaled accordingly.
        //
        // This results in total voting power 440_650_000 * 100 / 65 = 677_923_076.9230769
        // 
        // CAP0 + CAP1 * n = x
        // CAP0 = x * 65 / 100
        // CAP1 * n = x * 35 / 100

        // x = CAP0 * 100 / 65

        // CAP0 + CAP1 * n = CAP0 * 100 / 65
        // CAP1 * n = (CAP0 * 100) / 65 - (CAP0 * 65) / 65
        // CAP1 * n = (CAP0 * 100 - CAP0 * 65) / 65
        // CAP1 * n = (CAP0 * 35) / 65
        // CAP1 * n = CAP0 * (35 / 65)
        //       n = (CAP0 / CAP1) * (35 / 65)

        return id == 0 ? amount : (amount / 1e9) * 1e9 * (440_650_000 * 35) / (350_000 * 65);
    }

    // IAllocationMinter -----------------------------------------------------

    function allocationMint(address to, bytes32 role, uint256 amount)
        public
        override
        onlyRole(role)
    {
        Slice memory slice = allocationSlice(role);
        uint total = curves[role].calcGrowth(block.timestamp).mulu(slice.units * 1e5) / 1e5;
        uint256 available = total > slice.minted ? total - slice.minted : 0;
        require(amount <= available, "amount exceeds emissions available");
        _onAllocationMint(role, amount);
        _mint(to, slice.tokenId, amount, "");
    }

    function allocationSupplyAt(bytes32 role, uint256 timestamp)
        public
        view
        override
        returns (uint256)
    {
        return curves[role].calcGrowth(timestamp).mulu(allocationSlice(role).units * 1e5) / 1e5;
    }

    function allocationAvailable(bytes32 role)
        public
        view
        override
        returns (uint256)
    {
        Slice memory slice = allocationSlice(role);
        uint total = curves[role].calcGrowth(block.timestamp).mulu(slice.units * 1e5) / 1e5;
        return total > slice.minted ? total - slice.minted : 0;
    }

    function allocationMinted(bytes32 role)
        public
        view
        override
        returns (uint256)
    {
        return allocationSlice(role).minted;
    }

    // IERC165 ---------------------------------------------------------------

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC20_1155Votes, AccessControl)
        returns (bool)
    {
        return
            ERC20_1155Votes.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }
}