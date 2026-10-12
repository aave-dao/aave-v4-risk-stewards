// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHubConfigurator} from 'aave-v4/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'aave-v4/spoke/interfaces/ISpokeConfigurator.sol';

import {IRiskSteward} from 'src/interfaces/IRiskSteward.sol';

/// @title RiskStewardConfigs
/// @author Aave Labs
/// @notice Configs applied to a `RiskSteward` at deployment. Markets with specific needs
/// override the relevant fields of the default config.
library RiskStewardConfigs {
  /// @notice Returns the default config, identical on every network. Only the configurators are
  /// network specific.
  /// @param hubConfigurator The HubConfigurator of the network.
  /// @param spokeConfigurator The SpokeConfigurator of the network.
  /// @return The default config.
  function defaultConfig(
    IHubConfigurator hubConfigurator,
    ISpokeConfigurator spokeConfigurator
  ) internal pure returns (IRiskSteward.Config memory) {
    return
      IRiskSteward.Config({
        hub: IRiskSteward.HubConfig({
          configurator: hubConfigurator,
          rate: IRiskSteward.HubRateConfig({
            optimalUsageRatio: IRiskSteward.RiskParamConfig({
              minDelay: 36 hours,
              maxPercentChange: 3_00,
              isChangeRelative: false
            }),
            baseDrawnRate: IRiskSteward.RiskParamConfig({
              minDelay: 36 hours,
              maxPercentChange: 3_00,
              isChangeRelative: false
            }),
            rateGrowthBeforeOptimal: IRiskSteward.RiskParamConfig({
              minDelay: 36 hours,
              maxPercentChange: 3_00,
              isChangeRelative: false
            }),
            rateGrowthAfterOptimal: IRiskSteward.RiskParamConfig({
              minDelay: 36 hours,
              maxPercentChange: 20_00,
              isChangeRelative: false
            })
          }),
          cap: IRiskSteward.HubCapConfig({
            addCap: IRiskSteward.RiskParamConfig({
              minDelay: 36 hours,
              maxPercentChange: 100_00,
              isChangeRelative: true
            }),
            drawCap: IRiskSteward.RiskParamConfig({
              minDelay: 36 hours,
              maxPercentChange: 100_00,
              isChangeRelative: true
            })
          })
        }),
        spoke: IRiskSteward.SpokeConfig({
          configurator: spokeConfigurator,
          collateralRisk: IRiskSteward.RiskParamConfig({
            minDelay: 36 hours,
            maxPercentChange: 300_00,
            isChangeRelative: false
          }),
          dynamicUpdate: IRiskSteward.SpokeDynamicConfig({
            collateralFactor: IRiskSteward.RiskParamConfig({
              minDelay: 72 hours,
              maxPercentChange: 50,
              isChangeRelative: false
            }),
            maxLiquidationBonus: IRiskSteward.RiskParamConfig({
              minDelay: 72 hours,
              maxPercentChange: 50,
              isChangeRelative: false
            })
          }),
          dynamicAdd: IRiskSteward.SpokeDynamicConfig({
            collateralFactor: IRiskSteward.RiskParamConfig({
              minDelay: 72 hours,
              maxPercentChange: 5_00,
              isChangeRelative: false
            }),
            maxLiquidationBonus: IRiskSteward.RiskParamConfig({
              minDelay: 72 hours,
              maxPercentChange: 50,
              isChangeRelative: false
            })
          }),
          liquidation: IRiskSteward.SpokeLiquidationConfig({
            targetHealthFactor: IRiskSteward.RiskParamConfig({
              minDelay: 72 hours,
              maxPercentChange: 5_00,
              isChangeRelative: true
            }),
            healthFactorForMaxBonus: IRiskSteward.RiskParamConfig({
              minDelay: 72 hours,
              maxPercentChange: 5_00,
              isChangeRelative: true
            }),
            liquidationBonusFactor: IRiskSteward.RiskParamConfig({
              minDelay: 72 hours,
              maxPercentChange: 5_00,
              isChangeRelative: false
            })
          })
        }),
        oracle: IRiskSteward.OracleConfig({
          priceCapLst: IRiskSteward.RiskParamConfig({
            minDelay: 72 hours,
            maxPercentChange: 5_00,
            isChangeRelative: true
          }),
          priceCapStable: IRiskSteward.RiskParamConfig({
            minDelay: 72 hours,
            maxPercentChange: 50,
            isChangeRelative: true
          }),
          discountRatePendle: IRiskSteward.RiskParamConfig({
            minDelay: 48 hours,
            maxPercentChange: 0.025e18,
            isChangeRelative: false
          })
        })
      });
  }

  /// @notice Returns the config of the Base stocks market: the default config with shorter delays
  /// on hub caps and on spoke dynamic and liquidation configs.
  /// @param hubConfigurator The HubConfigurator of the network.
  /// @param spokeConfigurator The SpokeConfigurator of the network.
  /// @return config The Base stocks market config.
  function baseStocksConfig(
    IHubConfigurator hubConfigurator,
    ISpokeConfigurator spokeConfigurator
  ) internal pure returns (IRiskSteward.Config memory config) {
    config = defaultConfig(hubConfigurator, spokeConfigurator);

    config.hub.cap.addCap.minDelay = 12 hours;
    config.hub.cap.drawCap.minDelay = 12 hours;

    config.spoke.dynamicUpdate.collateralFactor.minDelay = 36 hours;
    config.spoke.dynamicUpdate.maxLiquidationBonus.minDelay = 36 hours;
    config.spoke.dynamicAdd.collateralFactor.minDelay = 36 hours;
    config.spoke.dynamicAdd.maxLiquidationBonus.minDelay = 36 hours;
    config.spoke.liquidation.targetHealthFactor.minDelay = 36 hours;
    config.spoke.liquidation.healthFactorForMaxBonus.minDelay = 36 hours;
    config.spoke.liquidation.liquidationBonusFactor.minDelay = 36 hours;
  }
}
