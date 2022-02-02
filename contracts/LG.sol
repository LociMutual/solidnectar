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

    bytes32 public constant LGY_ALLOCATION       = keccak256("LGY_ALLOCATION");
    bytes32 public constant AUCTION22_ALLOCATION = keccak256("AUCTION22_ALLOCATION");
    bytes32 public constant RESERVED_ALLOCATION  = keccak256("RESERVED_ALLOCATION");

    constructor(address governor, string memory baseURI)
        ERC1155Votes("Loci Global", "LG4", baseURI, 2)
        AllocationControl(governor)
        EmissionCurves(governor)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, governor);

        allocationAllocate(LGY_ALLOCATION,       1,     350_000 * 1e18);
        allocationAllocate(AUCTION22_ALLOCATION, 0,  99_000_000 * 1e18);
        allocationAllocate(RESERVED_ALLOCATION,  0, 341_650_000 * 1e18);

        require(allocationTotalSupplyCap()       == 441_000_000 * 1e18);
        require(allocationSupplyCapPerTokenId(0) == 440_650_000 * 1e18);
        require(allocationSupplyCapPerTokenId(1) ==     350_000 * 1e18);

        setCurve(
            AUCTION22_ALLOCATION,
            block.timestamp,
                 3600, 30,  // 1 hour ramp-up e^3.0x
                86400,      // 1 day of max emissions
            7 * 86400, 30); // 1 week of decay e^-3.0x
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