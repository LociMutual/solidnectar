// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ABDKMath64x64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/** 
 * @title ContinuousCallableConvertable
 * @dev Implements a continuous callable convertable token
 */
contract CallableConvertableContinuousBond is Ownable {
    using SafeERC20 for IERC20;
    using ABDKMath64x64 for int128;

    event Mint(address indexed _to, uint _value);
    event Burn(address indexed _from, uint value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
    event Transfer(address indexed _from, address indexed _to, uint _value);

    uint public immutable termMonths; // 0, 1, 2, 3, 4, 6, 12, 24, 60, 120

    struct Terms {
        uint day;
        int128 rate; // 64.64 bit 1 + annual/365
    }

    Terms[] public terms;

    IERC20 public immutable conversionToken;
    uint public immutable conversionRate;

    IERC20 public immutable returnToken;
    uint public immutable returnMultiplier;

    struct Checkpoint {
        uint termIndex;
        uint day;
        uint total;
    }

    mapping(address => Checkpoint) public checkpoints;
    Checkpoint aggregate;

    mapping(address => mapping(address => uint)) public allowances;

    /** 
     * @dev Create a new continuous callable convertable.
     * @param _termMonths number of months before new rate takes effect.
     * @param rate 64.64 bit 1 + annual/365
     * @param _returnMultiplier how many return tokens returned per this.balanceOf.
     * @param _returnToken token returned when called.
     * @param _conversionRate number of conversionTokens convertable per this.balanceOf.
     * @param _conversionToken token this converts to.
     */
    constructor(uint _termMonths, int128 rate, uint _returnMultiplier, address _returnToken, uint _conversionRate, address _conversionToken) {
        terms.push(Terms(block.timestamp, rate));
        termMonths = _termMonths;
        conversionToken = IERC20(_conversionToken);
        conversionRate = _conversionRate;
        returnToken = IERC20(_returnToken);
        returnMultiplier = _returnMultiplier;
    }

    function mint(address _to, uint _value) public onlyOwner {
        uint _today = _dayNumberOf(block.timestamp);

        checkpoints[_to] = _checkpoint(_today, checkpoints[_to]);
        checkpoints[_to].total += _value;
    
        aggregate = _checkpoint(_today, aggregate);
        aggregate.total += _value;

        emit Mint(_to, _value);
    }

    function burn(address _from, uint _value) public onlyOwner {
        uint _today = _dayNumberOf(block.timestamp);

        aggregate = _checkpoint(_today, aggregate);
        require(aggregate.total >= _value);
        checkpoints[_from] = _checkpoint(_today, checkpoints[_from]);
        require(checkpoints[_from].total >= _value);

        aggregate.total += _value;
        checkpoints[_from].total -= _value;

        emit Burn(_from, _value);
    }

    function approve(address _spender, uint _value) public {
        require(_value == 0 || allowances[msg.sender][_spender] == 0);
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
    }

    function allowance(address _owner, address _spender) public view returns (uint) {
        return allowances[_owner][_spender];
    }

    function transfer(address _to, uint _value) public {
        _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) public {
        if (msg.sender != _from) {
            require(allowances[_from][msg.sender] >= _value);
            allowances[_from][msg.sender] -= _value;
        }
        _transfer(_from, _to, _value);
    }

    function _transfer(address _from, address _to, uint _value) internal {
        uint _today = _dayNumberOf(block.timestamp);

        checkpoints[msg.sender] = _checkpoint(_today, checkpoints[msg.sender]);
        require(checkpoints[msg.sender].total >= _value);
    
        checkpoints[_to] = _checkpoint(_today, checkpoints[_to]);

        checkpoints[msg.sender].total -= _value;
        checkpoints[_to].total += _value;

        emit Transfer(_from, _to, _value);
    }

    function totalSupply() public view returns (uint) {
        return _checkpoint(_dayNumberOf(block.timestamp), aggregate).total;
    }

    function balanceOf(address addr) public view returns (uint) {
        return _checkpoint(_dayNumberOf(block.timestamp), checkpoints[addr]).total;
    }

    function _checkpoint(uint _day, Checkpoint memory checkpoint) internal view returns (Checkpoint memory) {
        if (_day == checkpoint.day) {
            return checkpoint;
        }
    
        require(checkpoint.day >= terms[checkpoint.termIndex].day);

        while (terms[checkpoint.termIndex].day <= _day) {
            uint _intervalStart = terms[checkpoint.termIndex].day;
            if (checkpoint.day > _intervalStart) {
                _intervalStart = checkpoint.day;
            }
            uint _days;
            if (terms.length > checkpoint.termIndex && _day > terms[checkpoint.termIndex + 1].day) {
                _days = terms[checkpoint.termIndex + 1].day - _intervalStart;
            }
            else {
                _days = _day - _intervalStart;
            }
            // TODO
            // checkpoint.total *= terms[checkpoint.termIndex].rate.pow(_days);
            if (terms.length > checkpoint.termIndex) {
                break;
            }
            ++checkpoint.termIndex;
        }

        checkpoint.day = _day;
        return checkpoint;
    }

    function _dayNumberOf(uint256 time) internal pure returns (uint256) {
        return 0;
    }
}
