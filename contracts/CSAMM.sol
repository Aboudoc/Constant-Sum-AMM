// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IERC20.sol";

contract CSAMM {
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address _token0, address _token1) {
        // assuming both tokens have same decimals
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    function _mint(address _to, uint256 _amount) private {
        totalSupply += _amount;
        balanceOf[_to] += _amount;
    }

    function _burn(address _from, uint256 _amount) private {
        totalSupply -= _amount;
        balanceOf[_from] -= _amount;
    }

    function _update(uint256 _res0, uint256 _res1) private {
        reserve0 = _res0;
        reserve1 = _res1;
    }

    function addLiquidity(uint256 _token0, uint256 _token1) external returns (uint256 shares) {
        // a: amount
        // L: liquidity
        // s: shares to mint
        // T: total shares
        // (a + L) / L = (s + T) / T
        // <=> (a + L)T = (s + L)L <=> aT + LT = sL + LT <=> aT = sL <=> (dx + dy)T = s(X + Y)
        // => s = (dx +dy)T / (X + Y)
        token0.transferFrom(msg.sender, address(this), _token0);
        token1.transferFrom(msg.sender, address(this), _token1);

        uint256 bal0 = token0.balanceOf(address(this));
        uint256 bal1 = token1.balanceOf(address(this));

        uint256 d0 = bal0 - reserve0;
        uint256 d1 = bal1 - reserve1;

        if (totalSupply > 0) {
            shares = ((d0 + d1) * totalSupply) / (reserve0 + reserve1);
            _update(_token0, _token1);
        } else {
            shares = _token0 + _token1;
        }

        require(shares > 0);
        _mint(msg.sender, shares);
        _update(bal0, bal1);
    }

    function removeLiquidity(uint256 _shares) external returns (uint256 d0, uint256 d1) {
        // a / L = s / T <=> aT = sL => (dx + dy)T = s(X + Y) <=> dx + dy = s(X + Y) / T
        // <=> dx + dy = sX / T  + sY / T
        // => dx = sX / T and dy = sY / T
        d0 = (_shares * reserve0) / totalSupply;
        d1 = (_shares * reserve1) / totalSupply;
        _burn(msg.sender, _shares);
        token0.transfer(msg.sender, d0);
        token1.transfer(msg.sender, d1);
        _update(reserve0 - d0, reserve1 - d1);
    }

    function swap(address _tokenIn, uint256 _amountIn) external returns (uint256 amountOut) {
        // X + dx + Y - dy = k
        // dx = dy
        require(_tokenIn == address(token0) || _tokenIn == address(token1));
        bool isToken0 = (_tokenIn == address(token0));

        (IERC20 tokenIn, IERC20 tokenOut, uint256 resIn, uint256 resOut) = isToken0
            ? (token0, token1, reserve0, reserve1)
            : (token1, token0, reserve1, reserve0);

        uint256 amountIn = token0.balanceOf(address(this)) - reserve0;

        tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        amountOut = (amountIn * 997) / 1000;
        (uint256 res0, uint256 res1) = isToken0 ? (resIn + amountIn, resOut - amountOut) : (resOut - amountOut, resIn + amountIn);

        _update(res0, res1);
        tokenOut.transfer(msg.sender, amountOut);
    }
}
