// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

// https://soenkeba.medium.com/truly-decentralized-nfts-by-erc-1155-b9be28db2aae

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/** 
 * @title DecentralizedERC1155
 * @dev Accounts for multiple tokens backed by multiple forms of tokenized collateral.
 */
contract DecentralizedERC1155 is ERC1155 {
    constructor() ERC1155("ipfs://f0{id}") {}

    /**
     * @dev Returns the URI for token type `id`.
     * @param id The token's ID.
     * @return The URI for the token.
     */
    function uri(uint256 _id)
        override public view
        returns (string memory)
    {
        string memory _hexstringtokenID = uint2hexstr(_id);
        return string(abi.encodePacked("ipfs://f0", _hexstringtokenID));
    }

    function uint2hexstr(uint256 i)
        public pure
        returns (string memory)
    {
        if (i == 0) return "0";
        uint j = i;
        uint length;
        while (j != 0) {
            length++;
            j = j >> 4;
        }
        uint mask = 15;
        bytes memory bstr = new bytes(length);
        uint k = length;
        while (i != 0) {
            uint curr = (i & mask);
            bstr[--k] = curr > 9 ?
                bytes1(uint8(55 + curr)) :
                bytes1(uint8(48 + curr)); // 55 = 65 - 10
            i = i >> 4;
        }
        return string(bstr);
    }
}
