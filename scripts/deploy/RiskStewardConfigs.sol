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

  /// @notice Returns the config of the Sentora market. Its steward is only driven through the
  /// `ReduceRiskStewardWrapper`, which only cuts caps and collateral factors, so the caps and the
  /// added dynamic config get loose bounds with no delay and every other param is frozen.
  /// @param hubConfigurator The Sentora HubConfigurator.
  /// @param spokeConfigurator The Sentora SpokeConfigurator.
  /// @return config The Sentora market config.
  function sentoraConfig(
    IHubConfigurator hubConfigurator,
    ISpokeConfigurator spokeConfigurator
  ) internal pure returns (IRiskSteward.Config memory config) {
    config = defaultConfig(hubConfigurator, spokeConfigurator);

    config.hub.rate.optimalUsageRatio = _frozen(config.hub.rate.optimalUsageRatio);
    config.hub.rate.baseDrawnRate = _frozen(config.hub.rate.baseDrawnRate);
    config.hub.rate.rateGrowthBeforeOptimal = _frozen(config.hub.rate.rateGrowthBeforeOptimal);
    config.hub.rate.rateGrowthAfterOptimal = _frozen(config.hub.rate.rateGrowthAfterOptimal);
    config.hub.cap.addCap = _bound(config.hub.cap.addCap, 300_00);
    config.hub.cap.drawCap = _bound(config.hub.cap.drawCap, 300_00);

    config.spoke.collateralRisk = _frozen(config.spoke.collateralRisk);
    config.spoke.dynamicUpdate.collateralFactor = _frozen(
      config.spoke.dynamicUpdate.collateralFactor
    );
    config.spoke.dynamicUpdate.maxLiquidationBonus = _frozen(
      config.spoke.dynamicUpdate.maxLiquidationBonus
    );
    config.spoke.dynamicAdd.collateralFactor = _bound(
      config.spoke.dynamicAdd.collateralFactor,
      100_00
    );
    config.spoke.dynamicAdd.maxLiquidationBonus = _bound(
      config.spoke.dynamicAdd.maxLiquidationBonus,
      50_00
    );
    config.spoke.liquidation.targetHealthFactor = _frozen(
      config.spoke.liquidation.targetHealthFactor
    );
    config.spoke.liquidation.healthFactorForMaxBonus = _frozen(
      config.spoke.liquidation.healthFactorForMaxBonus
    );
    config.spoke.liquidation.liquidationBonusFactor = _frozen(
      config.spoke.liquidation.liquidationBonusFactor
    );

    config.oracle.priceCapLst = _frozen(config.oracle.priceCapLst);
    config.oracle.priceCapStable = _frozen(config.oracle.priceCapStable);
    config.oracle.discountRatePendle = _frozen(config.oracle.discountRatePendle);
  }

  // Keeps the param's relative/absolute mode, which `RiskSteward.setConfig` enforces per field.
  function _bound(
    IRiskSteward.RiskParamConfig memory param,
    uint208 maxPercentChange
  ) private pure returns (IRiskSteward.RiskParamConfig memory) {
    return
      IRiskSteward.RiskParamConfig({
        minDelay: 0,
        maxPercentChange: maxPercentChange,
        isChangeRelative: param.isChangeRelative
      });
  }

  function _frozen(
    IRiskSteward.RiskParamConfig memory param
  ) private pure returns (IRiskSteward.RiskParamConfig memory) {
    return _bound(param, 0);
  }
}
