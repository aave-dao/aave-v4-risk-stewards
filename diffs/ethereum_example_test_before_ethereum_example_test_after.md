## Spoke Reserve Changes

### WETH ([0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2](https://etherscan.io/address/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)) on Spoke [0x94e7A5dCbE816e498b89aB752661904E2F56c485](https://etherscan.io/address/0x94e7A5dCbE816e498b89aB752661904E2F56c485) [reserveId: 0]

| description      | value before | value after |
| ---------------- | ------------ | ----------- |
| dynamicConfigKey | 0            | 1           |

## Hub Asset Changes

### WETH (assetId: 0) on Hub [0xCca852Bc40e560adC3b1Cc58CA5b55638ce826c9](https://etherscan.io/address/0xCca852Bc40e560adC3b1Cc58CA5b55638ce826c9)

| description   | value before   | value after    |
| ------------- | -------------- | -------------- |
| baseDrawnRate | 0.00 % [0]     | 1.00 % [100]   |
| maxDrawnRate  | 16.35 % [1635] | 17.35 % [1735] |

## Hub Spoke Config Changes

### WETH (assetId: 0) on Hub [0xCca852Bc40e560adC3b1Cc58CA5b55638ce826c9](https://etherscan.io/address/0xCca852Bc40e560adC3b1Cc58CA5b55638ce826c9) / Spoke [0x94e7A5dCbE816e498b89aB752661904E2F56c485](https://etherscan.io/address/0x94e7A5dCbE816e498b89aB752661904E2F56c485)

| description | value before         | value after        |
| ----------- | -------------------- | ------------------ |
| addCap      | 18,500 (1.85e4) WETH | 20,000 (2e4) WETH  |
| drawCap     | 1,600 (1.6e3) WETH   | 1,700 (1.7e3) WETH |

## Spoke Liquidation Config Changes

### Spoke [0x94e7A5dCbE816e498b89aB752661904E2F56c485](https://etherscan.io/address/0x94e7A5dCbE816e498b89aB752661904E2F56c485)

| description        | value before               | value after                |
| ------------------ | -------------------------- | -------------------------- |
| targetHealthFactor | 1.24 [1240000000000000000] | 1.05 [1050000000000000000] |

## Raw diff

```json
{
  "hubAssets": {
    "0xCca852Bc40e560adC3b1Cc58CA5b55638ce826c9": {
      "0": {
        "baseDrawnRate": {
          "from": 0,
          "to": 100
        },
        "maxDrawnRate": {
          "from": "1635",
          "to": "1735"
        }
      }
    }
  },
  "spokeConfigs": {
    "0xCca852Bc40e560adC3b1Cc58CA5b55638ce826c9_0_0x94e7A5dCbE816e498b89aB752661904E2F56c485": {
      "addCap": {
        "from": 18500,
        "to": 20000
      },
      "drawCap": {
        "from": 1600,
        "to": 1700
      }
    }
  },
  "spokeLiquidationConfigs": {
    "0x94e7A5dCbE816e498b89aB752661904E2F56c485": {
      "targetHealthFactor": {
        "from": "1240000000000000000",
        "to": "1050000000000000000"
      }
    }
  },
  "spokeReserves": {
    "0x94e7A5dCbE816e498b89aB752661904E2F56c485": {
      "0": {
        "dynamicConfigKey": {
          "from": 0,
          "to": 1
        }
      }
    }
  }
}
```
