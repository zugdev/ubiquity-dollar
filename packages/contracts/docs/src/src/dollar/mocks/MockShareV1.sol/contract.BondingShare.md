# BondingShare
[Git Source](https://github.com/ubiquity/ubiquity-dollar/blob/562529d3970008a3b47fdae4073c66a60be478ff/src/dollar/mocks/MockShareV1.sol)

**Inherits:**
[StakingShare](/src/dollar/core/StakingShare.sol/contract.StakingShare.md)


## Functions
### constructor


```solidity
constructor();
```

### initialize


```solidity
function initialize(address _manager, string memory uri) public override initializer;
```

### hasUpgraded


```solidity
function hasUpgraded() public pure virtual returns (bool);
```

### getVersion


```solidity
function getVersion() public view virtual returns (uint8);
```

### getImpl


```solidity
function getImpl() public view virtual returns (address);
```

