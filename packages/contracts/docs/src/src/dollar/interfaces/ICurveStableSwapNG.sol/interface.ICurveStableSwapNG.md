# ICurveStableSwapNG
[Git Source](https://github.com/ubiquity/ubiquity-dollar/blob/447ec1d83d6aa0044c753bd31ba3571a47b64509/src/dollar/interfaces/ICurveStableSwapNG.sol)

**Inherits:**
[ICurveStableSwapMetaNG](/src/dollar/interfaces/ICurveStableSwapMetaNG.sol/interface.ICurveStableSwapMetaNG.md)

Curve's interface for plain pool which contains only USD pegged assets


## Functions
### add_liquidity


```solidity
function add_liquidity(uint256[] memory _amounts, uint256 _min_mint_amount, address _receiver)
    external
    returns (uint256);
```

