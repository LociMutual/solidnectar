// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ERC1155Votes.sol";
import "./AllocationControl.sol";
import "./EmissionCurves.sol";
import "./ABDKMath64x64.sol";
import "../interfaces/IAllocationMinter.sol";

/**
 */
contract LG is ERC1155Votes, AccessControl, AllocationControl, EmissionCurves, IAllocationMinter {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;

    // These may be dynamically extended by allocating new roles via AllocationControl.

    bytes32 public constant RESERVE_ALLOCATION      = keccak256("RESERVE_ALLOCATION");
    bytes32 public constant AUCTION_ALLOCATION      = keccak256("AUCTION_ALLOCATION");
    bytes32 public constant LAUNCH_C1_ALLOCATION    = keccak256("LAUNCH_C1_ALLOCATION");
    bytes32 public constant LAUNCH_C2_ALLOCATION    = keccak256("LAUNCH_C2_ALLOCATION");
    bytes32 public constant LAUNCH_C3_ALLOCATION    = keccak256("LAUNCH_C3_ALLOCATION");
    bytes32 public constant LAUNCH_C4_ALLOCATION    = keccak256("LAUNCH_C4_ALLOCATION");
    bytes32 public constant RECM_ALLOCATION         = keccak256("RECM_ALLOCATION");
    bytes32 public constant PIONEER_ALLOCATION      = keccak256("PIONEER_ALLOCATION");
    bytes32 public constant NECTAR_ALLOCATION       = keccak256("NECTAR_ALLOCATION");
    bytes32 public constant FOUNDATION_ALLOCATION   = keccak256("FOUNDATION_ALLOCATION");
    bytes32 public constant FOUNDATION_Y_ALLOCATION = keccak256("FOUNDATION_Y_ALLOCATION");
    bytes32 public constant G921_ALLOCATION         = keccak256("G921_ALLOCATION");
    bytes32 public constant DIVEMASTER_ALLOCATION   = keccak256("DIVEMASTER_ALLOCATION");
    bytes32 public constant BPITTMAN_ALLOCATION     = keccak256("BPITTMAN_ALLOCATION");
    bytes32 public constant VALCRON_ALLOCATION      = keccak256("VALCRON_ALLOCATION");
    bytes32 public constant MERGE_MGMT_ALLOCATION   = keccak256("MERGE_MGMT_ALLOCATION");
    bytes32 public constant MSCHWARTZ_ALLOCATION    = keccak256("MSCHWARTZ_ALLOCATION");
    bytes32 public constant EDW_ALLOCATION          = keccak256("EDW_ALLOCATION");
    bytes32 public constant ECARROLL_ALLOCATION     = keccak256("ECARROLL_ALLOCATION");
    bytes32 public constant JENNYB_ALLOCATION       = keccak256("JENNYB_ALLOCATION");
    bytes32 public constant LEGACY_ALLOCATION       = keccak256("LEGACY_ALLOCATION");

    constructor(address governor, string memory baseURI)
        ERC1155Votes("Loci Global", "LG4", baseURI, 2)
        AllocationControl(governor)
        EmissionCurves(governor)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, governor);

        allocationAllocate(     RESERVE_ALLOCATION, 0, 185_000_000 * 1e18);
        allocationAllocate(     AUCTION_ALLOCATION, 0,  99_000_000 * 1e18);
        allocationAllocate(   LAUNCH_C1_ALLOCATION, 0,  11_100_000 * 1e18);
        allocationAllocate(   LAUNCH_C2_ALLOCATION, 0,  11_100_000 * 1e18);
        allocationAllocate(   LAUNCH_C3_ALLOCATION, 0,  11_100_000 * 1e18);
        allocationAllocate(   LAUNCH_C4_ALLOCATION, 0,  20_700_000 * 1e18);
        allocationAllocate(        RECM_ALLOCATION, 0,  24_400_000 * 1e18);
        allocationAllocate(     PIONEER_ALLOCATION, 0,  22_000_000 * 1e18);
        allocationAllocate(      NECTAR_ALLOCATION, 0,  15_100_000 * 1e18);
        allocationAllocate(  FOUNDATION_ALLOCATION, 0,  11_650_000 * 1e18);
        allocationAllocate(FOUNDATION_Y_ALLOCATION, 1,     350_000 * 1e18);
        allocationAllocate(        G921_ALLOCATION, 0,   8_400_000 * 1e18);
        allocationAllocate(  DIVEMASTER_ALLOCATION, 0,   5_250_000 * 1e18);
        allocationAllocate(    BPITTMAN_ALLOCATION, 0,   4_250_000 * 1e18);
        allocationAllocate(     VALCRON_ALLOCATION, 0,   2_500_000 * 1e18);
        allocationAllocate(  MERGE_MGMT_ALLOCATION, 0,   2_500_000 * 1e18);
        allocationAllocate(   MSCHWARTZ_ALLOCATION, 0,   1_600_000 * 1e18);
        allocationAllocate(         EDW_ALLOCATION, 0,   1_580_000 * 1e18);
        allocationAllocate(    ECARROLL_ALLOCATION, 0,     350_000 * 1e18);
        allocationAllocate(      JENNYB_ALLOCATION, 0,     250_000 * 1e18);
        allocationAllocate(      LEGACY_ALLOCATION, 0,   2_820_000 * 1e18);

        require(allocationTotalSupplyCap()        ==   441_000_000 * 1e18);
        require(allocationSupplyCapPerTokenId(0)  ==   440_650_000 * 1e18);
        require(allocationSupplyCapPerTokenId(1)  ==       350_000 * 1e18);

        setCurve(
            AUCTION_ALLOCATION,
            block.timestamp,
                26 * 7 * 86400, 30,  // 6 months ramp-up e^3.0x
            1 * 52 * 7 * 86400,      // 1 year of max emissions
            3 * 52 * 7 * 86400, 30); // 3 years of decay e^-3.0x

        setCurve(
            RECM_ALLOCATION,
            block.timestamp,
            0, 0,  
            5 * 52 * 7 * 86400, // 5 years of max emissions
            0, 0);

        setCurve(
            NECTAR_ALLOCATION,
            block.timestamp,
            0, 0,  
            5 * 52 * 7 * 86400, // 5 years of max emissions
            0, 0);
    }

    function setURI(string memory newURI) public {
        _setURI(newURI);
    }

    function votingPower(uint256 id, uint256 amount)
        public pure override
        returns (uint256)
    {
        require(id < 2, "invalid class");
        if (id == 0) {
            // 65% is controlled by 440.65MM LG common shares
            return amount * 65 * 441_000_000 / 440_650_000_00;
        }
        else {
            // 35% is controlled by 350k LG-Y shares
            return amount * 35 * 441_000_000 /     350_000_00;
        }
    }

    // IAllocationMinter -----------------------------------------------------

    function allocationMint(address to, bytes32 role, uint256 amount)
        public override
        onlyRole(role)
    {
        Slice memory slice = allocationSlice(role);
        uint total = calcGrowth(role, block.timestamp).mulu(slice.units * 1e5) / 1e5;
        uint256 available = total > slice.minted ? total - slice.minted : 0;
        require(amount <= available, "amount exceeds emissions available");
        _onAllocationMint(role, amount);
        _mint(to, slice.tokenId, amount, "");
    }

    function allocationSupplyAt(bytes32 role, uint256 timestamp)
        public view override
        returns (uint256)
    {
        return calcGrowth(role, timestamp).mulu(allocationSlice(role).units * 1e5) / 1e5;
    }

    function allocationAvailable(bytes32 role)
        public view override
        returns (uint256)
    {
        Slice memory slice = allocationSlice(role);
        uint total = calcGrowth(role, block.timestamp).mulu(slice.units * 1e5) / 1e5;
        return total > slice.minted ? total - slice.minted : 0;
    }

    function allocationMinted(bytes32 role)
        public view override
        returns (uint256)
    {
        return allocationUnitsMinted(role);
    }

    // IERC165 ---------------------------------------------------------------

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public view virtual
        override(ERC1155Votes, AccessControl)
        returns (bool)
    {
        return
            ERC1155Votes.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }
}