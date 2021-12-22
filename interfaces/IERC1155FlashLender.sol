// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "./IERC1155FlashBorrower.sol";

/**
 * @dev Interface of the ERC3156 FlashLender, as defined in
 * https://eips.ethereum.org/EIPS/eip-3156[ERC-3156] extended to support ERC1155.
 */
interface IERC1155FlashLender {
    /**
     * @dev The amount of currency available to be lended.
     * @param token The loan currency.
     * @param id The ERC1155 token ID.
     * @return The amount of `token` that can be borrowed.
     */
    function maxFlashLoan(address token, uint256 id) external view returns (uint256);

    /**
     * @dev The fee to be charged for a given loan.
     * @param token The loan currency.
     * @param id The ERC1155 token ID.
     * @param amount The amount of tokens lent.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(address token, uint256 id, uint256 amount) external view returns (uint256);

    /**
     * @dev Initiate a flash loan.
     * @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
     * @param token The loan currency.
     * @param id The ERC1155 token ID.
     * @param amount The amount of tokens lent.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     */
    function flashLoan(
        IERC1155FlashBorrower receiver,
        address token,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}