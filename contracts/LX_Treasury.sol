// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import "../interfaces/ILX20.sol";
import "./LX.sol";

address constant WETH9_mainnet = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant WETH9_rinkeby = 0xc778417E063141139Fce010982780140Aa0cD5Ab;

ISwapRouter constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
uint24 constant poolFee = 3000;

/**
 * @title Loci Global Treasury
 * @dev Accounts for a stable token backed by multiple forms of tokenized collateral.
 */
contract LX_Treasury is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant INITIALIZER_ROLE = keccak256("INITIALIZER_ROLE");

    // ERC20 for the asset e.g. LUSD, LARS, etc.
    ILX20 public token;

    IERC20 public immutable WETH9;

    // reserve requirements in basis points
    uint256[2] public minmaxReserve; // (1e5) e.g. 9300 = 93%

    // fees in basis points
    uint256[2] public minmaxOriginationFee; // (1e5) e.g. 111 = 1.11%
    uint256[2] public minmaxRedemptionFee;  // (1e5) e.g. 300 = 3%
    
    // collateral ERC20 token addresses
    // used for LGX origination
    //
    address[] public collateral;
    uint8[] public decimals;

    // Reserve target weights for each collateral, sum to 10000.
    // e.g. 9500 = 95%, 0 = token not accepted as collateral.
    //
    mapping(address => uint256) public targets; 

    // events

    event Originate(
        address originator,
        address receiver,
        uint256 value,
        address collateral,
        uint256 fee);

    event ReserveTargets(
        uint256[2] minmaxReserve);
    
    event Fees(
        uint256[2] minmaxOriginationFee,
        uint256[2] minmaxRedemptionFee);
    
    event Redeem(
        address collateralToken,
        uint256 value,
        uint256 fee);

    event Inflate(
        address to,
        uint256 value);

    event Withdraw(
        address to,
        uint256 value);

    event Mint(
        address recipient,
        uint256 value);

    event Burn(
        address account,
        uint256 value);

    constructor(
        address governor,
        address[] memory collateralTokens,
        uint8[] memory decimals_,
        uint256[] memory balanceTargets,
        uint256[2] memory minmaxReserve_,
        uint256[2] memory minmaxOriginationFee_,
        uint256[2] memory minmaxRedemptionFee_,
        IERC20 WETH9_)
    {
        require(collateralTokens.length == balanceTargets.length, "parameter array length mismatch");

        // eventually to DAO governance via multisig or perhaps a multi-treasury governor
        _grantRole(DEFAULT_ADMIN_ROLE, governor);

        // expected to renounce after initialize()
        _grantRole(INITIALIZER_ROLE, msg.sender);

        for (uint i = 0; i < collateralTokens.length; ++i) {
            collateral.push(collateralTokens[i]);
            decimals.push(decimals_[i]);
            targets[collateralTokens[i]] = balanceTargets[i];
        }

        minmaxReserve = minmaxReserve_;
        minmaxOriginationFee = minmaxOriginationFee_;
        minmaxRedemptionFee = minmaxRedemptionFee_;

        WETH9 = WETH9_;

        emit ReserveTargets(minmaxReserve_);
        emit Fees(minmaxOriginationFee_, minmaxRedemptionFee_);
    }

    function initialize(address lx)
        public
        onlyRole(INITIALIZER_ROLE)
    {
        token = ILX20(lx);

        // token may only be set once
        _revokeRole(INITIALIZER_ROLE, msg.sender);
    }

    /**
     * @dev As a cheaper alternative to an upgradeable proxy, transfer all assets to the new treasury contract.
     */
    function migrate(address payable newTreasury)
        public
        payable
        onlyRole(GOVERNOR_ROLE)
    {
        Ownable(address(token)).transferOwnership(newTreasury);

        for (uint i = 0; i < collateral.length; ++i) {
            uint256 bal = IERC20(collateral[i]).balanceOf(address(this));
            if (bal > 0) {
                IERC20(collateral[i]).safeTransfer(newTreasury, bal);
            }
        }

        if (address(this).balance > 0) {
            (bool sent, /*bytes memory data*/) = newTreasury.call{value: address(this).balance}("");
            require(sent, "failed to send eth");
        }
    }

    function accept(address collateralToken, uint256 balanceTarget)
        public
        onlyRole(GOVERNOR_ROLE)
    {
        targets[collateralToken] = balanceTarget;
        for (uint i = 0; i < collateral.length; ++i) {
            if (collateral[i] == collateralToken) {
                return;
            }
        }
        collateral.push(collateralToken);
    }

    function setReserveTargets(uint256[2] memory minmaxReserve_)
        public
        onlyRole(GOVERNOR_ROLE)
    {
        minmaxReserve = minmaxReserve_;
    
        emit ReserveTargets(minmaxReserve_);
    }

    function setFees(uint256[2] memory minmaxOriginationFee_, uint256[2] memory minmaxRedemptionFee_)
        public
        onlyRole(GOVERNOR_ROLE)
    {
        minmaxOriginationFee = minmaxOriginationFee_;
        minmaxRedemptionFee = minmaxRedemptionFee_;
    
        emit Fees(minmaxOriginationFee_, minmaxRedemptionFee_);
    }

    function getPreferredCollateral() public view returns (address preferred, uint8 decimals_) {
        preferred = collateral[0];
        decimals_ = decimals[0];
        uint256 minFilled = 2**256-1;
        for (uint i = 0; i < collateral.length; ++i) {
            uint256 target = token.totalSupply() * targets[collateral[i]] / 10000;
            uint256 actual = IERC20(collateral[i]).balanceOf(address(this));
            if (target > 0) {
                uint256 filled = 10000 * actual / target;
                if (minFilled > filled) {
                    minFilled = filled;
                    preferred = collateral[i];
                    decimals_ = decimals[i];
                }
            }
        }
    }

    receive()
        external
        payable
    {
        // There's not much to go on here so we must allow any amount of slippage.
        originate(msg.sender, 0, block.timestamp);
    }

    function originate(address receiver, uint256 amountOutMin, uint256 deadline)
        public
        payable
    {
        (address collateralToken, uint8 decimals_) = getPreferredCollateral();
        uint256 value = swapETHforCollateral(msg.value, collateralToken, amountOutMin, deadline);
        uint256 fee = originationFee(collateralToken, value);
        uint256 valueOriginated = value * (10000 - fee) / 10000;
        token.mint(receiver, valueOriginated);
        emit Originate(msg.sender, receiver, valueOriginated, collateralToken, fee);

    }

    function originate(address receiver, address collateralToken, uint256 value)
        public
    {
        originateFrom(msg.sender, receiver, collateralToken, value);
    }

    // IERC20Permit-based originate to save gas on collateralToken.approve
    //
    function originate(address owner, address receiver, address collateralToken, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
    {
        IERC20Permit(collateralToken).permit(owner, address(this), value, deadline, v, r, s);
        originateFrom(owner, receiver, collateralToken, value);
    }

    // Sender must have already ERC20 approved this contract to transfer _collateralToken from sender.
    //
    function originateFrom(address owner, address receiver, address collateralToken, uint256 value)
        public
    {
        require(targets[collateralToken] > 0, "collateral not accepted");
        uint256 fee = originationFee(collateralToken, value);
        uint256 valueOriginated = value * (10000 - fee) / 10000;
        IERC20(collateralToken).safeTransferFrom(owner, address(this), value);
        token.mint(receiver, valueOriginated);
        emit Originate(owner, receiver, valueOriginated, collateralToken, fee);
    }

    function redeem(address collateralToken, uint256 value)
        public
    {
        uint256 fee = redemptionFee(collateralToken, value);
        token.burnFrom(msg.sender, value);
        IERC20(collateralToken).safeTransfer(msg.sender, value * (10000 - fee) / 10000);
        emit Redeem(collateralToken, value, fee);
    }

    function withdraw(address to, address collateralToken, uint256 value)
        public
        onlyRole(GOVERNOR_ROLE)
    {
        uint256 actual = IERC20(collateralToken).balanceOf(address(this));
        uint256 target = token.totalSupply() * minmaxReserve[0] * targets[collateralToken] / 100000000;
        require(actual - value >= target, "insufficient reserves");
        IERC20(collateralToken).safeTransfer(to, value);
        emit Withdraw(to, value);
    }

    // Occasionally the community will want to inflate the LUSD supply
    // to match the realized profits from fees.  This is one mechanism whereby
    // a Governor transaction may inflate the supply and use the minted LUSD
    // to buy back bonds (LB) from the ecosystem.
    //
    function inflate(address to, uint256 value)
        public
        onlyRole(GOVERNOR_ROLE)
    {
        uint256 target = (value + token.totalSupply()) * minmaxReserve[0] / 10000;
        uint256 reserves = aggregateReserves();
        require(reserves >= target, "exceeds min reserve target");
        token.mint(to, value);
        emit Inflate(msg.sender, value);
        emit Mint(to, value);
    }

    function aggregateReserves() public view returns (uint256 total) {
        for (uint i = 0; i < collateral.length; ++i) {
            total += IERC20(collateral[i]).balanceOf(address(this));
        }
    }

    function originationFee(address collateralToken, uint256 value)
        public
        view
        returns (uint256)
    {
        uint256 target = token.totalSupply() * minmaxReserve[1] * targets[collateralToken] / 100000000;
        uint256 actual = IERC20(collateralToken).balanceOf(address(this)) + value;
        return actual > target ? minmaxOriginationFee[1] : minmaxOriginationFee[0];
    }

    function redemptionFee(address collateralToken, uint256 value)
        public
        view
        returns (uint256)
    {
        uint256 target = token.totalSupply() * minmaxReserve[0] * targets[collateralToken] / 100000000;
        uint256 actual = IERC20(collateralToken).balanceOf(address(this)) - value;
        return actual < target ? minmaxRedemptionFee[1] : minmaxRedemptionFee[0];
    }

    function swapETHforCollateral(
        uint256 value,
        address tokenOut,
        uint256 amountOutMinimum,
        uint256 deadline
    )
        internal
        returns (uint256)
    {
        payable(address(WETH9)).transfer(value);
        WETH9.approve(address(swapRouter), msg.value);

        ISwapRouter.ExactInputSingleParams memory params = 
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(WETH9),
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: address(this),
                deadline: deadline,
                amountIn: value,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            });

        return swapRouter.exactInputSingle(params);
    }
}
