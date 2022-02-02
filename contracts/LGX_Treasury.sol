// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import "../interfaces/IGLX20.sol";
import "../interfaces/IPoolManager.sol";
import "./LGX.sol";

/** 
 * @title Loci Global Treasury
 * @dev Accounts for multiple tokens backed by multiple forms of tokenized collateral.
 */
contract LGX_Treasury is AccessControl, IERC3156FlashLender {
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant UX_ROLE = keccak256("UX_ROLE");

    bytes32 private constant FLASH_RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");

    // ERC20 for the asset e.g. LUSD, LARS, etc.
    ILGX20 public token;

    // reserve requirements in basis points
    uint256[2] public minmaxReserve; // (1e5) e.g. 9300 = 93%

    // portion of reserves that may be invested in swap pools
    uint256[2] public minmaxPooled; // (1e5) e.g. 1000 = 10%

    // fees in basis points
    uint256[2] public minmaxOriginationFee; // (1e5) e.g. 111 = 1.11%
    uint256[2] public minmaxRedemptionFee;  // (1e5) e.g. 300 = 3%
    uint256 public flashLoanFee;            // (1e5) e.g. 111 = 1.11%
    
    // collateral ERC20 tokens
    // (including LPTokens from supported swap pools)
    // used for LGX origination
    //
    address[] public collateral;

    // Reserve target weights for each collateral, sum to 10000.
    // e.g. 9500 = 95%, 0 = token not accepted as collateral.
    //
    mapping(address => uint256) public targets; 
        
    // Swap pools to earn APY on sticky LGX reserves.
    //
    IPoolManager[] pools;

    // events

    event Originate(
        address originator,
        address receiver,
        uint256 value,
        address collateral,
        uint256 fee);

    event Targets(
        uint256[2] minmaxReserve,
        uint256[2] minmaxPooled);
    
    event Fees(
        uint256[2] minmaxOriginationFee,
        uint256[2] minmaxRedemptionFee,
        uint256 flashLoanFee);

    event Asset(
        string name,
        string symbol,
        address[] collateralTokens,
        uint256[] balanceTargets);
    
    event Redeem(
        address collateralToken,
        uint256 value,
        uint256 fee);

    event Mint(
        address recipient,
        uint256 value);

    event Burn(
        address account,
        uint256 value);

    // functions

    constructor(
        address governor,
        string memory name,
        string memory symbol,
        address[] memory collateralTokens,
        uint256[] memory balanceTargets,
        uint256[2] memory minmaxReserve_,
        uint256[2] memory minmaxPooled_,
        uint256[2] memory minmaxOriginationFee_,
        uint256[2] memory minmaxRedemptionFee_,
        uint256 flashLoanFee_
    )
    {
        require(collateralTokens.length == balanceTargets.length, "parameter array length mismatch");

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNOR_ROLE, governor);

        token = new LGX(name, symbol);
    
        for (uint i = 0; i < collateralTokens.length; ++i) {
            collateral.push(collateralTokens[i]);
            targets[collateralTokens[i]] = balanceTargets[i];
        }

        minmaxReserve = minmaxReserve_;
        minmaxPooled = minmaxPooled_;
        minmaxOriginationFee = minmaxOriginationFee_;
        minmaxRedemptionFee = minmaxRedemptionFee_;
        flashLoanFee = flashLoanFee_;

        emit Targets(minmaxReserve_, minmaxPooled_);
        emit Fees(minmaxOriginationFee_, minmaxRedemptionFee_, flashLoanFee_);
    }

    function setTargets(uint256[2] memory minmaxReserve_, uint256[2] memory minmaxPooled_)
        public
        onlyRole(GOVERNOR_ROLE)
    {
        minmaxReserve = minmaxReserve_;
        minmaxPooled = minmaxPooled_;
    
        emit Targets(minmaxReserve_, minmaxPooled_);
    }

    function setFees(uint256[2] memory minmaxOriginationFee_, uint256[2] memory minmaxRedemptionFee_, uint256 flashLoanFee_)
        public
        onlyRole(GOVERNOR_ROLE)
    {
        minmaxOriginationFee = minmaxOriginationFee_;
        minmaxRedemptionFee = minmaxRedemptionFee_;
        flashLoanFee = flashLoanFee_;
    
        emit Fees(minmaxOriginationFee_, minmaxRedemptionFee_, flashLoanFee_);
    }

    // Sender must have already ERC20 approved this contract to transfer _collateralToken from sender.
    // DAO primordial L1 governor must have already deposited pre-allocated tokens for origination.
    //
    function originate(uint256 value, address collateralToken, address receiver)
        public
    {
        require(token.balanceOf(address(this)) >= value, "debt ceiling hit");
        require(targets[collateralToken] > 0, "collateral not accepted");
        uint256 fee = originationFee(collateralToken, value);
        uint256 valueOriginated = value * (10000 - fee) / 10000;
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), value);
        token.transfer(receiver, valueOriginated);
        emit Originate(msg.sender, receiver, valueOriginated, collateralToken, fee);
    }

    function redeem(address collateralToken, uint256 value)
        public
    {
        uint256 fee = redemptionFee(collateralToken, value);
        token.burnFrom(msg.sender, value);
        IERC20(collateralToken).safeTransfer(msg.sender, value * (10000 - fee) / 10000);
        emit Redeem(collateralToken, value, fee);
    }

    function deposit(address collateralToken, uint256 value)
        public
        onlyRole(GOVERNOR_ROLE)
    {
        uint256 actual = IERC20(collateralToken).balanceOf(address(this));
        uint256 target = token.totalSupply() * minmaxReserve[1] * targets[collateralToken] / 100000000;
        require(actual + value <= target, "exceeds max reserve target");
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), value);
    }

    function withdraw(address collateralToken, uint256 value)
        public
        onlyRole(GOVERNOR_ROLE)
    {
        uint256 actual = IERC20(collateralToken).balanceOf(address(this));
        uint256 target = token.totalSupply() * minmaxReserve[0] * targets[collateralToken] / 100000000;
        require(actual - value >= target, "insufficient reserves");
        IERC20(collateralToken).safeTransfer(msg.sender, value);
    }

    // Occasionally the community will want to inflate the LUSD supply to match
    // the realized profits from liquidity pools.  This is one mechanism whereby
    // a Governor transaction could inflate the supply and use the minted LUSD
    // to buy back bonds (LGB) from the ecosystem.
    //
    function inflate(uint256 value)
        public
        onlyRole(GOVERNOR_ROLE)
    {
        uint256 target = (value + token.totalSupply()) * minmaxReserve[0] / 10000;
        uint256 reserves = 0;
        for (uint i = 0; i < collateral.length; ++i) {
            reserves += IERC20(collateral[i]).balanceOf(address(this));
        }
        require(reserves >= target, "exceeds min reserve target");
        token.mint(msg.sender, value);
        emit Mint(msg.sender, value);
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

    function maxFlashLoan(address loanedToken)
        public
        view
        override
        returns (uint256)
    {
        if (loanedToken == address(token)) {
            // native asset loan, the sky is the limit
            return type(uint256).max - token.totalSupply();
        }
        else {
            // loan from collateral reserves
            return IERC20(loanedToken).balanceOf(address(this));
        }
    }

    /**
     * @dev Returns the fee applied when doing flash loans.
     * @param loanedToken The token to be flash loaned.
     * @param amount The amount of tokens to be loaned.
     * @return The fees applied to the corresponding flash loan.
     */
    function flashFee(address loanedToken, uint256 amount)
        public
        view
        override
        returns (uint256)
    {
        return amount * flashLoanFee / 10000;
    }

    /**
     * @dev Performs a flash loan. New tokens are minted and sent to the
     * `receiver`, who is required to implement the {IERC3156FlashBorrower}
     * interface. By the end of the flash loan, the receiver is expected to own
     * amount + fee tokens and have them approved back to the token contract itself so
     * they can be burned.
     * @param receiver The receiver of the flash loan. Should implement the
     * {IERC3156FlashBorrower.onFlashLoan} interface.
     * @param loanedToken The token to be flash loaned. Only `address(this)` is
     * supported.
     * @param amount The amount of tokens to be loaned.
     * @param data An arbitrary datafield that is passed to the receiver.
     * @return `true` is the flash loan was successful.
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address loanedToken,
        uint256 amount,
        bytes calldata data
    )
        public
        virtual
        override
        returns (bool)
    {
        uint256 fee = flashFee(loanedToken, amount);
        if (loanedToken == address(token)) {
            token.mint(address(receiver), amount);
        }
        else {
            token.transferFrom(address(this), address(receiver), amount);
        }
        require(
            receiver.onFlashLoan(msg.sender, loanedToken, amount, fee, data) == FLASH_RETURN_VALUE,
            "ERC20FlashMint: invalid return value"
        );
        uint256 currentAllowance = IERC20(loanedToken).allowance(address(receiver), address(this));
        require(currentAllowance >= amount + fee, "ERC20FlashMint: allowance does not allow refund");
        IERC20(loanedToken).approve(address(receiver), currentAllowance - amount - fee);
        if (loanedToken == address(token)) {
            token.burnFrom(address(receiver), amount + fee);
        }
        else {
            IERC20(loanedToken).transferFrom(address(receiver), address(this), amount);
        }
        return true;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC3156FlashLender).interfaceId ||
            AccessControl.supportsInterface(interfaceId);
    }
}
