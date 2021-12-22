// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "abdk-consulting/abdk-libraries-solidity/ABDKMath64x64.sol";
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

    uint public termMonths; // 0, 1, 2, 3, 4, 6, 12, 24, 60, 120

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
     * @param termMonths number of months before new rate takes effect.
     * @param rate 64.64 bit 1 + annual/365
     * @param returnMultiplier how many return tokens returned per this.balanceOf.
     * @param returnToken token returned when called.
     * @param conversionMultiplier number of conversionTokens convertable per this.balanceOf.
     * @param conversionToken token this converts to.
     */
    constructor(uint termMonths, int128 rate, uint returnMultiplier, address returnToken, uint conversionRate, address conversionToken) {
        terms.push(Terms(block.timestamp, growthRate));
    }

    function mint(address _to, uint _value) public isOwner {
        uint _today = _dayNumberOf(now());

        checkpoints[_to] = _checkpoint(_today, checkpoints[_to]);
        checkpoints[_to].total += _value;
    
        aggregate = _checkpoint(_today, aggregate);
        aggregate.total += _value;

        emit Mint(_to, _value);
    }

    function burn(address _from, uint _value) public isOwner {
        uint _today = _dayNumberOf(now());

        aggregate = _checkpoint(_today, aggregate);
        require(aggregate.total >= _value);
        checkpoints[_from] = _checkpoint(_today, checkpoints[_from]);
        require(checkpoints[_from].total >= _value);

        aggregate.total += _value;
        checkpoints[_from].total -= _value;

        emit Burn(_from, _value);
    }

    function approve(address _spender, uint _value) public {
        require(_value == 0 || allowance[msg.sender][_spender] == 0);
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
    }

    function allowance(address _owner, address _spender) view returns (uint) {
        return allowances[_owner][_spender];
    }

    function transfer(address _to, uint _value) public {
        _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) public {
        if (msg.sender != _from) {
            require(allowance[_from][msg.sender] >= _value);
            allowance[_from][msg.sender] -= _value;
        }
        _transfer(_from, _to, _value);
    }

    function _transfer(address _from, address _to, uint _value) internal {
        uint _today = _dayNumberOf(now());

        checkpoints[msg.sender] = _checkpoint(_today, checkpoints[msg.sender]);
        require(checkpoints[msg.sender].total >= _value);
    
        checkpoints[_to] = _checkpoint(_today, checkpoints[_to]);

        checkpoints[msg.sender].total -= _value;
        checkpoints[_to].total += _value;

        emit Transfer(_from, _to, _value);
    }

    function totalSupply() view returns (uint) {
        return _checkpoint(_dayNumberOf(now()), aggregate).total;
    }

    function balanceOf(address addr) view returns (uint) {
        return _checkpoint(_dayNumberOf(now()), checkpoints[addr]).total;
    }

    function _checkpoint(uint _day, Checkpoint checkpoint) internal view returns (Checkpoint) {
        if (_day == checkpoint.day) {
            return checkpoint;
        }
    
        require(checkpoint.day >= terms[checkpoint.termIndex].day);

        while (terms[checkpoint.termIndex].dayNumber <= _day) {
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
            checkpoint.total *= pow(terms[checkpoint.termIndex].rate, _days);
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
