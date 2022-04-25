// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

address constant WETH9_mainnet = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant WETH9_rinkeby = 0xc778417E063141139Fce010982780140Aa0cD5Ab;

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    /// @notice Creates a new position wrapped in a NFT
    /// @dev Call this when the pool does exist and is initialized. Note that if the pool is created but not initialized
    /// a method does not exist, i.e. the pool is assumed to be initialized.
    /// @param params The params necessary to mint a position, encoded as `MintParams` in calldata
    /// @return tokenId The ID of the token that represents the minted position
    /// @return liquidity The amount of liquidity for this position
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );
}

/**
 * @title Generic ERC20 burnable token
 * @notice Generic ERC20 token that is mintable and burnable for testing.
 */
contract MockERC20 is ERC20, ERC20Burnable, ERC20Permit {
    address public immutable WETH9;
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV3Factory public swapFactory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    uint24 constant poolFee = 3000;
    IUniswapV3Pool public immutable pool;
    INonfungiblePositionManager public constant positions = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    /**
     * @notice Deploy this contract with given name, symbol, and decimals
     * @dev the caller of this constructor will become the owner of this contract
     * @param name_ name of this token
     * @param symbol_ symbol of this token
     */
    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
    {
        uint256 id;
        assembly {
            id := chainid()
        }
        address WETH9_ = id == 1 ? WETH9_mainnet : WETH9_rinkeby;
        WETH9 = WETH9_;
        pool = IUniswapV3Pool(swapFactory.createPool(WETH9_, address(this), poolFee));
        pool.initialize(sqrt(price) * 2 ** 96);
    }

    function addLiquidity(uint256 price) payable public {
        require(price != 0, "price == 0");

        uint256 amount = msg.value * price / 1e18;
        _mint(address(this), amount);

        //payable(address(WETH9)).transfer(msg.value);
        (bool sent, /*bytes memory data*/) = WETH9.call{value: msg.value}("");
        require(sent, "failed to wrap ETH");

        IERC20(WETH9).approve(address(positions), msg.value);

        INonfungiblePositionManager.MintParams memory params =
            INonfungiblePositionManager.MintParams({
                token0: WETH9,
                token1: address(this),
                fee: poolFee,
                tickLower: -887272,
                tickUpper:  887272,
                amount0Desired: msg.value,
                amount1Desired: amount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: msg.sender,
                deadline: block.timestamp
            });

        /*(tokenId, liquidity, amount0, amount1) =*/ positions.mint(params);
    }

    /**
     * @notice Mints given amount of tokens to recipient
     * @param recipient address of account to receive the tokens
     * @param amount amount of tokens to mint
     */
    function mint(address recipient, uint256 amount)
        public
    {
        require(amount != 0, "amount == 0");
        _mint(recipient, amount);
    }
}
