// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "../interfaces/IGLX20.sol";

// 1,000,000,000 minted on L1, bridged to SKALE by admin account, and deposited in L2 LGX_Treasury.

contract LGX is ERC20, AccessControl, ERC20Permit, ILGX20 {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
        ERC20Permit(name)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount)
        public
        override
        onlyRole(MINTER_ROLE)
    {
        _mint(to, amount);
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount)
        public
        override
    {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount)
        public
        override
    {
        if (!hasRole(MINTER_ROLE, msg.sender)) {
            uint256 currentAllowance = allowance(account, msg.sender);
            require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
            unchecked {
                _approve(account, msg.sender, currentAllowance - amount);
            }
        }
        _burn(account, amount);
    }
}
