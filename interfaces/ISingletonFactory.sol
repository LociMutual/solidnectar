// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

interface ISingletonFactory {
    function deploy(
        bytes calldata initCode,
        bytes32 salt
    ) external returns (address payable deployedContract);
}
