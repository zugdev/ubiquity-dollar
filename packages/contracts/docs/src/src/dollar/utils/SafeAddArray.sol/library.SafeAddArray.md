# SafeAddArray
[Git Source](https://github.com/ubiquity/ubiquity-dollar/blob/2eddcfb55b36b43d0000788d070925b81d328b5a/src/dollar/utils/SafeAddArray.sol)

Wrappers over Solidity's array push operations with added check


## Functions
### add

Adds `value` to `array`


```solidity
function add(uint256[] storage array, uint256 value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`array`|`uint256[]`|Array to modify|
|`value`|`uint256`|Value to add|


### add

Adds `values` to `array`


```solidity
function add(uint256[] storage array, uint256[] memory values) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`array`|`uint256[]`|Array to modify|
|`values`|`uint256[]`|Array of values to add|


