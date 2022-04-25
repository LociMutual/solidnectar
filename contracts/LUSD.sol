// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./LX.sol";

contract LUSD is LX {
    constructor(address owner) LX(owner, "Loci USD", "LUSD") {}
}
