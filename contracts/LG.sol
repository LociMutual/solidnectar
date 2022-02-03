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

    bytes32 public constant RESERVE_ALLOCATION          = keccak256("RESERVE_ALLOCATION");
    bytes32 public constant AUCTION_ALLOCATION          = keccak256("AUCTION_ALLOCATION");
    bytes32 public constant RECM_ALLOCATION             = keccak256("RECM_ALLOCATION");
    bytes32 public constant PIONEER_ALLOCATION          = keccak256("PIONEER_ALLOCATION");
    bytes32 public constant NECTAR_ALLOCATION           = keccak256("NECTAR_ALLOCATION");
    bytes32 public constant DAO_FOUNDATION_ALLOCATION   = keccak256("FOUNDATION_ALLOCATION");
    bytes32 public constant DAO_FOUNDATION_Y_ALLOCATION = keccak256("FOUNDATION_Y_ALLOCATION");

    bytes32 public constant INVESTOR_01_ALLOCATION      = keccak256("INVESTOR_01_ALLOCATION");
    bytes32 public constant INVESTOR_02_ALLOCATION      = keccak256("INVESTOR_02_ALLOCATION");
    bytes32 public constant INVESTOR_03_ALLOCATION      = keccak256("INVESTOR_03_ALLOCATION");
    bytes32 public constant INVESTOR_04_ALLOCATION      = keccak256("INVESTOR_04_ALLOCATION");
    bytes32 public constant INVESTOR_05_ALLOCATION      = keccak256("INVESTOR_05_ALLOCATION");
    bytes32 public constant INVESTOR_06_ALLOCATION      = keccak256("INVESTOR_06_ALLOCATION");
    bytes32 public constant INVESTOR_07_ALLOCATION      = keccak256("INVESTOR_07_ALLOCATION");
    bytes32 public constant INVESTOR_08_ALLOCATION      = keccak256("INVESTOR_08_ALLOCATION");
    bytes32 public constant INVESTOR_09_ALLOCATION      = keccak256("INVESTOR_09_ALLOCATION");

    bytes32 public constant INVESTOR_10_ALLOCATION      = keccak256("INVESTOR_10_ALLOCATION");
    bytes32 public constant INVESTOR_11_ALLOCATION      = keccak256("INVESTOR_11_ALLOCATION");
    bytes32 public constant INVESTOR_12_ALLOCATION      = keccak256("INVESTOR_12_ALLOCATION");
    bytes32 public constant INVESTOR_13_ALLOCATION      = keccak256("INVESTOR_13_ALLOCATION");
    bytes32 public constant INVESTOR_14_ALLOCATION      = keccak256("INVESTOR_14_ALLOCATION");
    bytes32 public constant INVESTOR_15_ALLOCATION      = keccak256("INVESTOR_15_ALLOCATION");
    bytes32 public constant INVESTOR_16_ALLOCATION      = keccak256("INVESTOR_16_ALLOCATION");
    bytes32 public constant INVESTOR_17_ALLOCATION      = keccak256("INVESTOR_17_ALLOCATION");
    bytes32 public constant INVESTOR_18_ALLOCATION      = keccak256("INVESTOR_18_ALLOCATION");
    bytes32 public constant INVESTOR_19_ALLOCATION      = keccak256("INVESTOR_19_ALLOCATION");

    bytes32 public constant INVESTOR_20_ALLOCATION      = keccak256("INVESTOR_20_ALLOCATION");
    bytes32 public constant INVESTOR_21_ALLOCATION      = keccak256("INVESTOR_21_ALLOCATION");
    bytes32 public constant INVESTOR_22_ALLOCATION      = keccak256("INVESTOR_22_ALLOCATION");
    bytes32 public constant INVESTOR_23_ALLOCATION      = keccak256("INVESTOR_23_ALLOCATION");
    bytes32 public constant INVESTOR_24_ALLOCATION      = keccak256("INVESTOR_24_ALLOCATION");
    bytes32 public constant INVESTOR_25_ALLOCATION      = keccak256("INVESTOR_25_ALLOCATION");
    bytes32 public constant INVESTOR_26_ALLOCATION      = keccak256("INVESTOR_26_ALLOCATION");
    bytes32 public constant INVESTOR_27_ALLOCATION      = keccak256("INVESTOR_27_ALLOCATION");

    bytes32 public constant LAUNCH_C1_ALLOCATION        = keccak256("LAUNCH_C1_ALLOCATION");
    bytes32 public constant LAUNCH_C2_ALLOCATION        = keccak256("LAUNCH_C2_ALLOCATION");
    bytes32 public constant LAUNCH_C3_ALLOCATION        = keccak256("LAUNCH_C3_ALLOCATION");
    bytes32 public constant LAUNCH_C4_ALLOCATION        = keccak256("LAUNCH_C4_ALLOCATION");

    constructor(address governor, string memory baseURI)
        ERC1155Votes("Loci Global", "LG4", baseURI, 2)
        AllocationControl(governor)
        EmissionCurves(governor)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, governor);

        _allocationAllocate(         RESERVE_ALLOCATION, 0, 185_000_000 * 1e18);
        _allocationAllocate(         AUCTION_ALLOCATION, 0,  99_000_000 * 1e18);

        // Gaurdians

        _allocationAllocate(            RECM_ALLOCATION, 0,  24_400_000 * 1e18);
        _allocationAllocate(         PIONEER_ALLOCATION, 0,  20_000_000 * 1e18);
        _allocationAllocate(          NECTAR_ALLOCATION, 0,  15_100_000 * 1e18);
        _allocationAllocate(  DAO_FOUNDATION_ALLOCATION, 0,  11_650_000 * 1e18);
        _allocationAllocate(DAO_FOUNDATION_Y_ALLOCATION, 1,     350_000 * 1e18);

        // Legacy & Seed Investors

        _allocationAllocate(     INVESTOR_01_ALLOCATION, 0,   8_400_000 * 1e18);
        _allocationAllocate(     INVESTOR_02_ALLOCATION, 0,   5_250_000 * 1e18);
        _allocationAllocate(     INVESTOR_03_ALLOCATION, 0,   4_250_000 * 1e18);
        _allocationAllocate(     INVESTOR_04_ALLOCATION, 0,   2_500_000 * 1e18);
        _allocationAllocate(     INVESTOR_05_ALLOCATION, 0,   2_500_000 * 1e18);
        _allocationAllocate(     INVESTOR_06_ALLOCATION, 0,   1_600_000 * 1e18);
        _allocationAllocate(     INVESTOR_07_ALLOCATION, 0,   1_580_000 * 1e18);
        _allocationAllocate(     INVESTOR_08_ALLOCATION, 0,     350_000 * 1e18);
        _allocationAllocate(     INVESTOR_09_ALLOCATION, 0,     250_000 * 1e18);

        _allocationAllocate(     INVESTOR_10_ALLOCATION, 0,     550_000 * 1e18);
        _allocationAllocate(     INVESTOR_11_ALLOCATION, 0,     550_000 * 1e18);
        _allocationAllocate(     INVESTOR_12_ALLOCATION, 0,     550_000 * 1e18);
        _allocationAllocate(     INVESTOR_13_ALLOCATION, 0,     275_000 * 1e18);
        _allocationAllocate(     INVESTOR_14_ALLOCATION, 0,     370_000 * 1e18);
        _allocationAllocate(     INVESTOR_15_ALLOCATION, 0,     100_000 * 1e18);
        _allocationAllocate(     INVESTOR_16_ALLOCATION, 0,     150_000 * 1e18);
        _allocationAllocate(     INVESTOR_17_ALLOCATION, 0,      25_000 * 1e18);
        _allocationAllocate(     INVESTOR_18_ALLOCATION, 0,     500_000 * 1e18);
        _allocationAllocate(     INVESTOR_19_ALLOCATION, 0,     500_000 * 1e18);

        _allocationAllocate(     INVESTOR_20_ALLOCATION, 0,     225_000 * 1e18);
        _allocationAllocate(     INVESTOR_21_ALLOCATION, 0,     175_000 * 1e18);
        _allocationAllocate(     INVESTOR_22_ALLOCATION, 0,     120_000 * 1e18);
        _allocationAllocate(     INVESTOR_23_ALLOCATION, 0,      20_000 * 1e18);
        _allocationAllocate(     INVESTOR_24_ALLOCATION, 0,       5_000 * 1e18);
        _allocationAllocate(     INVESTOR_25_ALLOCATION, 0,       5_000 * 1e18);
        _allocationAllocate(     INVESTOR_26_ALLOCATION, 0,     300_000 * 1e18);
        _allocationAllocate(     INVESTOR_27_ALLOCATION, 0,     400_000 * 1e18);

        // Blockchain Launch

        _allocationAllocate(       LAUNCH_C1_ALLOCATION, 0,  11_100_000 * 1e18); // Agents
        _allocationAllocate(       LAUNCH_C2_ALLOCATION, 0,  11_100_000 * 1e18); // Engineering, Ops
        _allocationAllocate(       LAUNCH_C3_ALLOCATION, 0,  11_100_000 * 1e18); // Property
        _allocationAllocate(       LAUNCH_C4_ALLOCATION, 0,  20_700_000 * 1e18); // Liquidity Rewards

        require(allocationTotalSupplyCap()        ==   441_000_000 * 1e18); // including unminted reserve
        require(allocationSupplyCapPerTokenId(0)  ==   440_650_000 * 1e18);
        require(allocationSupplyCapPerTokenId(1)  ==       350_000 * 1e18);

        _setCurve(
            AUCTION_ALLOCATION,
            block.timestamp,
                26 * 7 * 86400, 30,  // 6 months ramp-up e^3.0x
            1 * 52 * 7 * 86400,      // 1 year of max emissions
            3 * 52 * 7 * 86400, 30); // 3 years of decay e^-3.0x

        _setCurve(
            RECM_ALLOCATION,
            block.timestamp,
            3 * 52 * 7 * 86400, 20, // 3 years of ramp-up e^2x
            2 * 52 * 7 * 86400,     // 2 years of max emissions
            0, 0);

        _setCurve(
            NECTAR_ALLOCATION,
            block.timestamp,
            3 * 52 * 7 * 86400, 20, // 3 years of ramp-up e^2x
            2 * 52 * 7 * 86400,     // 2 years of max emissions
            0, 0);

        _setCurve(
            DAO_FOUNDATION_ALLOCATION,
            block.timestamp,
            3 * 52 * 7 * 86400, 20, // 3 years of ramp-up e^2x
            2 * 52 * 7 * 86400,     // 2 years of max emissions
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