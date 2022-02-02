// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

interface IPoolManager {                          // e.g.
    function getPool() external;                  //   BOOT_USDSWAP
    function getPoolToken() external;             //   BOOT_USDSWAP_LPToken
    function getPoolProtocolToken() external;     //   BOOT
    function getPoolProtocolVoteToken() external; // veBOOT

    function addLiquidity() external;             // -USDC, -USDT, ...; +BOOT_USDSWAP_LPToken
    function removeLiquidity() external;          // -BOOT_USDSWAP_LPToken; +USDC, +USDT, ...
    function swap() external;                     // -USDC; +USDT
    function lock() external;                     // -BOOT_USDSWAP_LPToken
    function unlock() external;                   // +BOOT_USDSWAP_LPToken
    function claim() external;                    // +BOOT, +SKL, ...
    function voteLock() external;                 // -BOOT; +veBOOT
    function voteUnlock() external;               // -veBOOT; +BOOT
    function vote() external;                     // veBOOT voting power -> (BOOT_USDSWAP, BOOT_ARSSWAP, ...)
}
