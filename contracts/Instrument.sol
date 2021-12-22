// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

// https://soenkeba.medium.com/truly-decentralized-nfts-by-erc-1155-b9be28db2aae

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./DecentralizedERC1155.sol";
import "./ERC1155FlashMint.sol";

/** 
 * @title Instrument
 * @dev Accounts for multiple tokens backed by multiple forms of tokenized collateral.
 */
contract Instrument is DecentralizedERC1155, ERC1155Supply, IERC1155FlashLender, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
    bytes32 public constant FIAT_CASHIER_ROLE = keccak256("FIAT_CASHIER_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    // initial asset/token IDs
    // TODO: replace this with a mapping
    uint256 public constant LUSD = 0x0;
    uint256 public constant LARS = 0x1;
    uint256 public constant LVES = 0x2;
    uint256 public constant LMXN = 0x3;
    uint256 public constant LEUR = 0x4;

    // fees in basis points
    uint256 public minOriginationFee; // * 10000 e.g. 111 = 1.11%
    uint256 public maxOriginationFee; // * 10000 e.g. 111 = 1.11%
    uint256 public minRedemptionFee;  // * 10000 e.g. 300 = 3%
    uint256 public maxRedemptionFee;  // * 10000 e.g. 300 = 3%
    uint256 public flashLoanFee;      // * 10000 e.g. 111 = 1.11%

    // reserve requirements in basis points
    uint256 public minReserve; // * 10000 e.g. 9300 = 93%
    uint256 public maxReserve; // * 10000 e.g. 9300 = 97%

    struct Asset {
        string[] name;
        string[] symbol;
        address treasury;
    }

    mapping(uint256 => Asset) public assets;

    // The reserve targets for a particular collateral token that should
    // all sum to 10000 for their respective asset.
    // * 10000 e.g. 9500 = 95%, 0 = token not accepted as collateral.
    //
    mapping(address => uint256) public targets; 

    // The asset ID associated with a particular collateral token.
    //
    mapping(address => uint256) public ids;

    // The number of collateral tokens per asset ID.
    //
    mapping(uint256 => uint256) public numTokens;

    // All collateral tokens for a particular asset ID.
    //
    mapping(uint256 => address[]) public tokens;

    // events

    event Originate(
        address originator,
        uint256 tokenId,
        uint256 value,
        uint256 fee);

    event Fees(
        uint256 minReserve,
        uint256 maxReserve,
        uint256 minOriginationFee,
        uint256 maxOriginationFee,
        uint256 minRedemptionFee,
        uint256 maxRedemptionFee);

    event Asset(
        uint256 tokenId,
        string name,
        string symbol,
        address[] collateralTokens,
        uint256[] balanceTargets);
    
    event Redeem(
        uint256 tokenId,
        address collateralToken,
        uint256 value,
        uint256 fee);

    event Mint(
        address recipient,
        uint256 tokenId,
        uint256 value);

    event Burn(
        address account,
        uint256 tokenId,
        uint256 value);

    // functions

    constructor(
        uint256 _minReserve,
        uint256 _maxReserve,
        uint256 _minOriginationFee,
        uint256 _maxOriginationFee,
        uint256 _minRedemptionFee,
        uint256 _maxRedemptionFee,
        uint256 _flashLoanFee
    )
    {
        // Grant the contract deployer the default admin role: it will be able
        // to grant and revoke any roles including revoking itself after assigning
        // GOV_ROLE to the one and only Governor.
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        // Certain roles must be voted by Governor.
        _setRoleAdmin(FIAT_CASHIER_ROLE, GOV_ROLE);
        _setRoleAdmin(TREASURY_ROLE, GOV_ROLE);

        minReserve = _minReserve;
        maxReserve = _maxReserve;
        minOriginationFee = _minOriginationFee;
        maxOriginationFee = _maxOriginationFee;
        minRedemptionFee = _minRedemptionFee;
        maxRedemptionFee = _maxRedemptionFee;

        emit Fees(_minReserve, _maxReserve, _minOriginationFee, _maxOriginationFee, _minRedemptionFee, _maxRedemptionFee);
    }

    function setFees(
        uint256 _minReserve,
        uint256 _maxReserve,
        uint256 _minOriginationFee,
        uint256 _maxOriginationFee,
        uint256 _minRedemptionFee,
        uint256 _maxRedemptionFee
    )
        public
        onlyRole(GOV_ROLE)
    {
        minReserve = _minReserve;
        maxReserve = _maxReserve;
        minOriginationFee = _minOriginationFee;
        maxOriginationFee = _maxOriginationFee;
        minRedemptionFee = _minRedemptionFee;
        maxRedemptionFee = _maxRedemptionFee;

        emit Fees(_minReserve, _maxReserve, _minOriginationFee, _maxOriginationFee, _minRedemptionFee, _maxRedemptionFee);
    }

    // Care must be taken to ensure that subsequent calls never remove a former collateral
    // token but instead set the balance targets to 0.  Otherwise some operations may
    // fail due to broken referential integrity between ids and other mappings.
    //
    function declareAsset(uint256 _id, string[] _name, string[] _symbol, address[] _collateralTokens, uint256[] _balanceTargets)
        public
        onlyRole(GOV_ROLE)
    {
        require(_collateralTokens.length == _targets.length, "parameter array length mismatch");
        numTokens[_id] = _collateralTokens.length;
        tokens[_id] = _collateralTokens;
        for (uint i = 0; i < _collateralTokens.length; ++i) {
            targets[_collateralTokens[i]] = _balanceTargets[i];
            ids[_collateralTokens[i]] = _id;
        }

        assets[_id] = Asset(_name, _symbol);

        emit Asset(_id, _name, _symbol, _collateralTokens, _balanceTargets);
    }

    // sender must have already ERC20 approved this contract to transfer _collateralToken from sender
    function originate(uint256 _id, uint256 _value, address _collateralToken, bytes memory _data)
        public
    {
        require(_to != address(0), "zero destination address");
        require(targets[_collateralToken] > 0, "collateral not accepted");
        uint256 _fee = originationFee(_id, _collateralToken, _value);
        uint256 _valueOriginated = _value * (10000 - _fee) / 10000;
        SafeERC20(_collateralToken).safeTransferFrom(_msgSender(), address(this), _value);
        _mint(_msgSender(), _id, _valueOriginated, _data);
        emit Originate(_msgSender(), _id, _valueOriginated, _fee);
    }

    function redeem(uint256 _id, address _collateralToken, uint256 _value, bytes memory data)
        public
    {
        uint256 _fee = redemptionFee(_id, _collateralToken, _value);
        _burn(_msgSender(), _id, _value);
        SafeERC20(_collateralToken).safeTransfer(_msgSender(), _value * (10000 - _fee) / 10000);
        emit Redeem(_id, _collateralToken, _value, _fee);
    }

    function deposit(address _token, uint256 _value)
        public
        onlyRole(TREASURY_ROLE)
    {
        uint256 _id = ids[_token];
        if (_id != 0) {
            require(_msgSender() == assets[_id].treasury, "unauthorized");
            uint256 _actual = SafeERC20(_token).balanceOf(address(this));
            uint256 _target = totalSupply(_id) * maxReserve * targets[_token] / 100000000;
            require(_actual + _value <= _target, "exceeds max reserve target");
        }
        SafeERC20(_token).safeTransferFrom(_msgSender(), address(this), _value);
    }

    function withdraw(address _token, uint256 _value)
        public
        onlyRole(TREASURY_ROLE)
    {
        uint256 _id = ids[_token];
        if (_id != 0) {
            require(_msgSender() == assets[_id].treasury, "unauthorized");
            uint256 _actual = SafeERC20(_token).balanceOf(address(this));
            uint256 _target = totalSupply(_id) * minReserve * targets[_token] / 100000000;
            require(_actual - _value >= _target, "insufficient reserves");
        }
        SafeERC20(_token).safeTransfer(_msgSender(), _value);
    }

    function originationFee(uint256 _id, address _collateralToken, uint256 _value)
        public view
        returns (uint256)
    {
        uint256 _target = totalSupply(_id) * maxReserve * targets[_collateralToken] / 100000000;
        uint256 _actual = SafeERC20(_collateralToken).balanceOf(address(this)) + _value;
        return _actual > _target ? maxOriginationFee : minOriginationFee;
    }

    function redemptionFee(uint256 _id, address _collateralToken, uint256 _value)
        public view
        returns (uint256)
    {
        uint256 _target = totalSupply(_id) * minReserve * targets[_collateralToken] / 100000000;
        uint256 _actual = SafeERC20(_collateralToken).balanceOf(address(this)) - _value;
        return _actual < _target ? maxRedemptionFee : minRedemptionFee;
    }

    // for approved fiat-backed agents
    function mint(uint256 _id, uint256 _value, bytes memory _data)
        public
        onlyRole(FIAT_CASHIER_ROLE)
    {
        uint256 _target = (_value + totalSupply(_id)) * minReserve / 10000;
        uint256 _reserves = 0;
        for (uint i = 0; i < numTokens[_id]; ++i) {
            _reserves += SafeERC20(tokens[_id][i]).balanceOf(address(this));
        }
        require(_reserves >= _target, "exceeds min reserve target");
        _mint(_msgSender(), _id, _value, _data);
        emit Mint(_msgSender(), _id, _value);
    }

    function burn(uint256 _id, uint256 _value)
        public
    {
        _burn(_msgSender(), _id, _value);
        emit Burn(_msgSender(), _id, _value);
    }

    function maxFlashLoan(address token, uint256 id)
        public view override
        returns (uint256)
    {
        if (token == address(this)) {
            // native asset loan, the sky is the limit
            return type(uint256).max - totalSupply(id);
        }
        else {
            // loan from collateral reserves
            require(id == 0, "expected ERC20 token that has no id");
            return SafeERC20(token).balanceOf(address(this));
        }
    }

    /**
     * @dev Returns the fee applied when doing flash loans.
     * @param token The token to be flash loaned, usually this.
     * @param id The tokenId to be flash loaned.
     * @param amount The amount of tokens to be loaned.
     * @return The fees applied to the corresponding flash loan.
     */
    function flashFee(address token, uint256 id, uint256 amount)
        public view override
        returns (uint256)
    {
        return amount * flashLoanFee / 10000;
    }

    /**
     * @dev Performs a flash loan. Collateral tokens are sent or new tokens are
     * minted and sent to the `receiver`, required to implement {IERC1155FlashBorrower}
     * interface. By the end of the flash loan, the receiver is expected to own
     * amount + fee tokens and have them approved back to the token contract itself so
     * they can be burned.
     * @param receiver The receiver of the flash loan. Should implement the
     * {IERC1155FlashBorrower.onFlashLoan} interface.
     * @param token The token to be flash loaned, either `address(this)` or an ERC20 reserve collateral token.
     * @param id ERC1155 token ID or 0 for ERC20 token.
     * @param amount The amount of tokens to be loaned.
     * @param data An arbitrary datafield that is passed to the receiver.
     * @return `true` is the flash loan was successful.
     */
    function flashLoan(
        IERC1155FlashBorrower receiver,
        address token,
        uint256 id,
        uint256 amount,
        bytes calldata data
    )
        public override
        returns (bool)
    {
        require(amount < maxFlashLoan(token, id), "exceeds maxFlashLoan");
        uint256 fee = flashFee(token, id, amount);
        if (token == address(this)) {
            _mint(address(receiver), id, amount, "");
        }
        else {
            SafeERC20(token).safeTransfer(receiver, amount);
        }
        require(
            receiver.onFlashLoan(_msgSender(), token, id, amount, fee, data) == _RETURN_VALUE,
            "onFlashLoan invalid return value"
        );
        if (token == address(this)) {
            _burn(address(receiver), id, amount + fee);
        }
        else {
            require(
                SafeERC20(token).safeAllowance(receiver, address(this)) >= amount,
                "Instrument must be approved to transfer loaned token"
            );
            SafeERC20(token).safeTransferFrom(receiver, address(this), amount + fee);
        }
        return true;
    }
}
