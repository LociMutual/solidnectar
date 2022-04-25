// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @dev declare and safegaurd token allocations.
 */
abstract contract AllocationControl is AccessControl {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // ALLOCATOR_ROLE is the admin for granting allocation roles.
    bytes32 public constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");

    // Other roles are defined dynamically to enable per-slice minting privileges.

    // For tracking mints against declared allocations.
    //
    struct Slice {
        uint256 tokenId;
        uint256 units;
        uint256 minted;
    }

    EnumerableSet.Bytes32Set private _roles;
    mapping(bytes32 => Slice) private _allocations;
    mapping(uint256 => uint256) private _supplyCapPerTokenId;
    uint256 private _totalSupplyCap;

    function allocationSlice(bytes32 role)
        public view
        returns (Slice memory)
    {
        return _allocations[role];
    }

    function allocationTotalSupplyCap()
        public view
        returns (uint256)
    {
        return _totalSupplyCap;
    }

    function allocationSupplyCapPerTokenId(uint256 tokenId)
        public view
        returns (uint256)
    {
        return _supplyCapPerTokenId[tokenId];
    }

    // Declares or adjusts a single allocation.
    //
    // 0. clear counters
    // 1. alter existing, recount units
    // 2. add new, count new units
    // 3. remove zeroed-out allocations only if not yet minted
    //
    function _allocationAllocate(bytes32 role, uint256 tokenId, uint256 units)
        internal
    {
        if (_roles.contains(role)) {
            // existing
            if (_allocations[role].minted > 0) {
                require(units >= _allocations[role].minted, "reallocation must include already minted slice");
                require(tokenId == _allocations[role].tokenId, "cannot change allocation's tokenId if already minted");
            }
            _totalSupplyCap -= _allocations[role].units;
            _supplyCapPerTokenId[tokenId] -= _allocations[role].units;
            _totalSupplyCap += units;
            _supplyCapPerTokenId[tokenId] += units;
            _allocations[role].units = units;
        }
        else {
            // new
            _roles.add(role);
            _setRoleAdmin(role, ALLOCATOR_ROLE);
            _totalSupplyCap += units;
            _supplyCapPerTokenId[tokenId] += units;
            _allocations[role] = Slice(tokenId, units, 0);
        }
    }

    function _onAllocationMint(bytes32 role, uint256 amount)
        internal
    {
        require(_allocations[role].minted + amount <= _allocations[role].units, "mint exceeds allocation");
        _allocations[role].minted += amount;
    }
}
