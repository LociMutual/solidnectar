// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../interfaces/ILX20.sol";

// AccessControl is needed to allow registration of a layer 2 minter,
// otherwise an Owner model would have been cheaper/easier.
//
contract LX is ERC20, ERC20Permit, ERC20FlashMint, Ownable, ERC165, ILX20 {

    constructor(address owner, string memory name, string memory symbol)
        ERC20(name, symbol)
        ERC20Permit(name)
    {
        _transferOwnership(owner);
    }

    function mint(address to, uint256 amount)
        public
        override
        onlyOwner
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
        if (msg.sender != owner()) {
            uint256 currentAllowance = allowance(account, msg.sender);
            require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
            unchecked {
                _approve(account, msg.sender, currentAllowance - amount);
            }
        }
        _burn(account, amount);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC20).interfaceId
            || interfaceId == type(IERC20Metadata).interfaceId
            || interfaceId == type(IERC20Permit).interfaceId
            || interfaceId == type(IERC3156FlashLender).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
