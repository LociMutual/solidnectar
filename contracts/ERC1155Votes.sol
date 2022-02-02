// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @dev Extension of ERC1155 to support Compound-like voting and delegation. This version is more generic than
 * Compound's, and supports token supply up to 2^224^ - 1, while COMP is limited to 2^96^ - 1.
 *
 * Multiple ERC1155 token ids represent different voting classes each having a distinct voting power multiplier.
 * Token ID 0 should represent the most common share so that the vast majority of accounts do not need
 * to send transactions to change the default token.
 *
 * This extension keeps a history (checkpoints) of each account's vote power. Vote power can be delegated either
 * by calling the {delegate} function directly, or by providing a signature to be used with {delegateBySig}. Voting
 * power can be queried through the public accessors {getVotes} and {getPastVotes}.
 *
 * By default, token balance does not account for voting power. This makes transfers cheaper. The downside is that it
 * requires users to delegate to themselves in order to activate checkpoints and have their voting power tracked.
 * Enabling self-delegation can easily be done by overriding the {delegates} function. Keep in mind however that this
 * will significantly increase the base gas cost of transfers.
 */
contract ERC1155Votes is ERC1155Supply, EIP712, IERC20Metadata {
    using Counters for Counters.Counter;

    uint256 private _n;               // number of token ids (share classes)
    uint256 private _aggregateSupply; // aggregate supply summed over all token ids
    string private _name;
    string private _symbol;

    // _defaultToken stores each account's default token used for ERC20 approvals/transfers.
    //
    // Since the mapping returns 0 by default it is recommended that the most common token class
    // be represented as tokenId == 0.  If tokenId 0 represents common shares, for example, then
    // this mapping will be sparsely filled.  Most accounts would never call setDefaultToken
    // to change the default since they would only ever hold the common class/share.
    //
    mapping(address => uint256) _defaultToken; // Default token ID for ERC20 approvals/tansfers.

    struct Checkpoint {
        uint32 fromBlock;
        uint224 votes;
    }

    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    mapping(address => address) private _delegates;
    mapping(address => Checkpoint[]) private _checkpoints;
    Checkpoint[] private _totalSupplyCheckpoints;

    mapping(address => Counters.Counter) private _nonces;

    // for ERC20 transfers only, not used for ERC1155 transfers
    mapping(address => mapping(address => uint256)) private _allowances;

    /**
     * @dev Emitted when an account changes their delegate.
     */
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /**
     * @dev Emitted when a token transfer or delegate change results in changes to an account's voting power.
     */
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    /**
     * @dev Constructs a set of `n` tokens with varying voting weights determined by a power function.
     */
    constructor(string memory name_, string memory symbol_, string memory uri_, uint256 n)
        ERC1155(uri_)
        EIP712(name_, "1")
    {
        _name = name_;
        _symbol = symbol_;
        _n = n;
    }

    function setDefaultToken(uint256 id) public {
        _defaultToken[msg.sender] = id;
    }

    function defaultToken() public view returns (uint256) {
        return _defaultToken[msg.sender];
    }

    /**
     * @dev Returns the IERC20Metadata name of the token set.
     */
    function name() external view override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the IERC20Metadata base symbol of all tokens.
     */
    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the IERC20Metadata decimals places of the tokens.
     */
    function decimals() external view override returns (uint8) {
        return 18;
    }

    /**
     * @dev Returns the aggregate total supply of all tokens regardless of token class.
     */
    function totalSupply() public view override returns (uint256 supply) {
        for (uint id = 0; id < _n; ++id) {
            supply += totalSupply(id);
        }
    }

    /**
     * @dev Returns the aggregate number of tokens over all classes owned by `account`.
     */
    function balanceOf(address account) public view override returns (uint256 balance) {
        for (uint id = 0; id < _n; ++id) {
            balance += balanceOf(account, id);
        }
    }

    /**
     * @dev Amount of `owner`'s default token approved for transfer by `spender`.
     */
    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev Approve transfers of up to `amount` of default token.
     */
    function approve(address spender, uint256 amount) external override returns (bool) {
        require(spender != address(0), "ERC20: transfer to the zero address");
        require(amount == 0 || _allowances[msg.sender][spender] == 0, "ERC20: potential double approval exploit");
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Transfer `amount` of default token from sender to `to` account.
     */
    function transfer(address to, uint256 amount) external override returns (bool) {
        _safeTransferFrom(msg.sender, to, _defaultToken[msg.sender], amount, "");
        // secondary event for the ERC20 interface
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @dev Transfer `amount` of common shares (token id == 0) from `from` account to `to` account.
     */
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        require(_allowances[msg.sender][from] >= amount, "ERC20: transfer exceeds allowance");
        _safeTransferFrom(from, to, _defaultToken[msg.sender], amount, "");
        // secondary event for the ERC20 interface
        emit Transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Get the voing power of an amount of tokens.
     */
    function votingPower(uint256 id, uint256 amount) public view virtual returns (uint256) {
        return amount;
    }

    /**
     * @dev Get the `pos`-th checkpoint for `account`.
     */
    function checkpoints(address account, uint32 pos) public view virtual returns (Checkpoint memory) {
        return _checkpoints[account][pos];
    }

    /**
     * @dev Get number of checkpoints for `account`.
     */
    function numCheckpoints(address account) public view virtual returns (uint32) {
        return SafeCast.toUint32(_checkpoints[account].length);
    }

    /**
     * @dev Get the address `account` is currently delegating to.
     */
    function delegates(address account) public view virtual returns (address) {
        return _delegates[account];
    }

    /**
     * @dev Gets the current votes balance for `account`
     */
    function getVotes(address account) public view returns (uint256) {
        uint256 pos = _checkpoints[account].length;
        return pos == 0 ? 0 : _checkpoints[account][pos - 1].votes;
    }

    /**
     * @dev Retrieve the number of votes for `account` at the end of `blockNumber`.
     *
     * Requirements:
     *
     * - `blockNumber` must have been already mined
     */
    function getPastVotes(address account, uint256 blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "ERC1155Votes: block not yet mined");
        return _checkpointsLookup(_checkpoints[account], blockNumber);
    }

    /**
     * @dev Retrieve the `totalSupply` at the end of `blockNumber`. Note, this value is the sum of all balances.
     * It is but NOT the sum of all the delegated votes!
     *
     * Requirements:
     *
     * - `blockNumber` must have been already mined
     */
    function getPastTotalSupply(uint256 blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "ERC1155Votes: block not yet mined");
        return _checkpointsLookup(_totalSupplyCheckpoints, blockNumber);
    }

    /**
     * @dev Lookup a value in a list of (sorted) checkpoints.
     */
    function _checkpointsLookup(Checkpoint[] storage ckpts, uint256 blockNumber) private view returns (uint256) {
        // We run a binary search to look for the earliest checkpoint taken after `blockNumber`.
        //
        // During the loop, the index of the wanted checkpoint remains in the range [low-1, high).
        // With each iteration, either `low` or `high` is moved towards the middle of the range to maintain the invariant.
        // - If the middle checkpoint is after `blockNumber`, we look in [low, mid)
        // - If the middle checkpoint is before or equal to `blockNumber`, we look in [mid+1, high)
        // Once we reach a single value (when low == high), we've found the right checkpoint at the index high-1, if not
        // out of bounds (in which case we're looking too far in the past and the result is 0).
        // Note that if the latest checkpoint available is exactly for `blockNumber`, we end up with an index that is
        // past the end of the array, so we technically don't find a checkpoint after `blockNumber`, but it works out
        // the same.
        uint256 high = ckpts.length;
        uint256 low = 0;
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (ckpts[mid].fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? 0 : ckpts[high - 1].votes;
    }

    /**
     * @dev Delegate votes from the sender to `delegatee`.
     */
    function delegate(address delegatee) public virtual {
        _delegate(_msgSender(), delegatee);
    }

    /**
     * @dev Delegates votes from signer to `delegatee`
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(block.timestamp <= expiry, "ERC1155Votes: signature expired");
        address signer = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(_DELEGATION_TYPEHASH, delegatee, nonce, expiry))),
            v,
            r,
            s
        );
        require(nonce == _useNonce(signer), "ERC1155Votes: invalid nonce");
        _delegate(signer, delegatee);
    }

    /**
     * @dev Maximum aggregate token supply. Defaults to `type(uint224).max` (2^224^ - 1).
     */
    function _maxSupply() internal view virtual returns (uint224 amount) {
        return type(uint224).max;
    }

    /**
     * @dev Snapshots the totalSupply after it has been increased.
     */
    function _mint(address account, uint256 id, uint256 amount, bytes memory data) internal virtual override {
        super._mint(account, id, amount, data);
        _aggregateSupply += amount;
        require(_aggregateSupply <= _maxSupply(), "ERC1155Votes: total supply risks overflowing votes");

        _writeCheckpoint(_totalSupplyCheckpoints, _add, votingPower(id, amount));
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Snapshots the totalSupply after it has been decreased.
     */
    function _burn(address account, uint256 id, uint256 amount) internal virtual override {
        super._burn(account, id, amount);
        _aggregateSupply -= amount;

        _writeCheckpoint(_totalSupplyCheckpoints, _subtract, votingPower(id, amount));
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual override {
        super._safeTransferFrom(from, to, id, amount, data);

        _moveVotingPower(delegates(from), delegates(to), votingPower(id, amount));
    }

    /**
     * @dev Change delegation for `delegator` to `delegatee`.
     *
     * Emits events {DelegateChanged} and {DelegateVotesChanged}.
     */
    function _delegate(address delegator, address delegatee) internal virtual {
        address currentDelegate = delegates(delegator);
        uint256 delegatorBalance = 0;
        for (uint32 id = 0; id < _n; ++id) {
            delegatorBalance += votingPower(id, balanceOf(delegator, id));
        }
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveVotingPower(
        address src,
        address dst,
        uint256 amount
    ) private {
        if (src != dst && amount > 0) {
            if (src != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(_checkpoints[src], _subtract, amount);
                emit DelegateVotesChanged(src, oldWeight, newWeight);
            }

            if (dst != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(_checkpoints[dst], _add, amount);
                emit DelegateVotesChanged(dst, oldWeight, newWeight);
            }
        }
    }

    function _writeCheckpoint(
        Checkpoint[] storage ckpts,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) private returns (uint256 oldWeight, uint256 newWeight) {
        uint256 pos = ckpts.length;
        oldWeight = pos == 0 ? 0 : ckpts[pos - 1].votes;
        newWeight = op(oldWeight, delta);

        if (pos > 0 && ckpts[pos - 1].fromBlock == block.number) {
            ckpts[pos - 1].votes = SafeCast.toUint224(newWeight);
        } else {
            ckpts.push(Checkpoint({fromBlock: SafeCast.toUint32(block.number), votes: SafeCast.toUint224(newWeight)}));
        }
    }

    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev "Consume a nonce": return the current value and increment.
     */
    function _useNonce(address owner) internal virtual returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC20).interfaceId ||
            interfaceId == type(IERC20Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}