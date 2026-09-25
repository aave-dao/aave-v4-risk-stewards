## Spoke Reserve Changes

### AAPLc ([0xb200000000000000000000C2e324d24d7eEcd1fb](https://basescan.org/address/0xb200000000000000000000C2e324d24d7eEcd1fb)) on Spoke [0x17905Db0e4A3514467539956c084180616AE7B8D](https://basescan.org/address/0x17905Db0e4A3514467539956c084180616AE7B8D) [reserveId: 0]

| description      | value before | value after |
| ---------------- | ------------ | ----------- |
| dynamicConfigKey | 0            | 1           |

**dynamicConfigs**

| key   | field               | before         | after          |
| ----- | ------------------- | -------------- | -------------- |
| key 0 | collateralFactor    | 78.00 % [7800] | 70.00 % [7000] |
| key 1 | collateralFactor    | _missing_      | 78.00 % [7800] |
| key 1 | maxLiquidationBonus | _missing_      | 5.50 % [10550] |
| key 1 | liquidationFee      | _missing_      | 10.00 % [1000] |

## Hub Asset Changes

### AAPLc (assetId: 0) on Hub [0xa4d5947Eb727A052bae69C593FfC84247EC9864E](https://basescan.org/address/0xa4d5947Eb727A052bae69C593FfC84247EC9864E)

| description   | value before | value after  |
| ------------- | ------------ | ------------ |
| baseDrawnRate | 0.00 % [0]   | 1.00 % [100] |
| maxDrawnRate  | 0.00 % [0]   | 1.00 % [100] |

## Hub Spoke Config Changes

### AAPLc (assetId: 0) on Hub [0xa4d5947Eb727A052bae69C593FfC84247EC9864E](https://basescan.org/address/0xa4d5947Eb727A052bae69C593FfC84247EC9864E) / Spoke [0x17905Db0e4A3514467539956c084180616AE7B8D](https://basescan.org/address/0x17905Db0e4A3514467539956c084180616AE7B8D)

| description | value before         | value after           |
| ----------- | -------------------- | --------------------- |
| addCap      | 15,000 (1.5e4) AAPLc | 16,500 (1.65e4) AAPLc |

## Spoke Liquidation Config Changes

### Spoke [0x17905Db0e4A3514467539956c084180616AE7B8D](https://basescan.org/address/0x17905Db0e4A3514467539956c084180616AE7B8D)

| description        | value before               | value after               |
| ------------------ | -------------------------- | ------------------------- |
| targetHealthFactor | 1.24 [1240000000000000000] | 1.2 [1200000000000000000] |

## Raw diff

```json
{
  "hubAssets": {
    "0xa4d5947Eb727A052bae69C593FfC84247EC9864E": {
      "0": {
        "baseDrawnRate": {
          "from": 0,
          "to": 100
        },
        "maxDrawnRate": {
          "from": "0",
          "to": "100"
        }
      }
    }
  },
  "spokeConfigs": {
    "0xa4d5947Eb727A052bae69C593FfC84247EC9864E_0_0x17905Db0e4A3514467539956c084180616AE7B8D": {
      "addCap": {
        "from": 15000,
        "to": 16500
      }
    }
  },
  "spokeLiquidationConfigs": {
    "0x17905Db0e4A3514467539956c084180616AE7B8D": {
      "targetHealthFactor": {
        "from": "1240000000000000000",
        "to": "1200000000000000000"
      }
    }
  },
  "spokeReserves": {
    "0x17905Db0e4A3514467539956c084180616AE7B8D": {
      "0": {
        "dynamicConfigKey": {
          "from": 0,
          "to": 1
        },
        "dynamicConfigs": {
          "0": {
            "collateralFactor": {
              "from": 7800,
              "to": 7000
            }
          },
          "1": {
            "from": null,
            "to": {
              "collateralFactor": 7800,
              "liquidationFee": 1000,
              "maxLiquidationBonus": 10550
            }
          }
        }
      }
    }
  }
}
```
