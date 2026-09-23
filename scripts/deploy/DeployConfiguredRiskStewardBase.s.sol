// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {AaveV4Base} from 'aave-address-book/AaveV4Base.sol';
import {GovernanceV3Base} from 'aave-address-book/GovernanceV3Base.sol';

import {RiskSteward} from 'src/RiskSteward.sol';
import {IRiskSteward} from 'src/interfaces/IRiskSteward.sol';

/// @title DeployConfiguredRiskStewardBase
/// @author Aave Labs
/// @notice Deploys the Base `RiskSteward` owned by the deployer, sets LlamaRisk's recommended config
/// for the Base Equities Hub, then starts the ownership transfer to the Executor. `Ownable2Step`
/// leaves the Executor as pending owner until it calls `acceptOwnership` through governance.
// make deploy-ledger contract=scripts/deploy/DeployConfiguredRiskStewardBase.s.sol:DeployConfiguredRiskStewardBase chain=base
contract DeployConfiguredRiskStewardBase is BaseScript {
  function run() external {
    (, address deployer, ) = vm.readCallers();

    vm.startBroadcast();
    RiskSteward riskSteward = new RiskSteward(AaveV4Base.RISK_COUNCIL, deployer);
    riskSteward.setConfig(_llamaRiskConfig());
    riskSteward.transferOwnership(GovernanceV3Base.EXECUTOR_LVL_1);
    vm.stopBroadcast();
  }

  function _llamaRiskConfig() internal pure returns (IRiskSteward.Config memory) {
    return
      IRiskSteward.Config({
        hub: IRiskSteward.HubConfig({
          configurator: AaveV4Base.HUB_CONFIGURATOR,
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
              minDelay: 12 hours,
              maxPercentChange: 200_00,
              isChangeRelative: true
            }),
            drawCap: IRiskSteward.RiskParamConfig({
              minDelay: 12 hours,
              maxPercentChange: 200_00,
              isChangeRelative: true
            })
          })
        }),
        spoke: IRiskSteward.SpokeConfig({
          configurator: AaveV4Base.SPOKE_CONFIGURATOR,
          collateralRisk: IRiskSteward.RiskParamConfig({
            minDelay: 36 hours,
            maxPercentChange: 300_00,
            isChangeRelative: false
          }),
          dynamicUpdate: IRiskSteward.SpokeDynamicConfig({
            collateralFactor: IRiskSteward.RiskParamConfig({
              minDelay: 36 hours,
              maxPercentChange: 50,
              isChangeRelative: false
            }),
            maxLiquidationBonus: IRiskSteward.RiskParamConfig({
              minDelay: 36 hours,
              maxPercentChange: 50,
              isChangeRelative: false
            })
          }),
          dynamicAdd: IRiskSteward.SpokeDynamicConfig({
            collateralFactor: IRiskSteward.RiskParamConfig({
              minDelay: 36 hours,
              maxPercentChange: 5_00,
              isChangeRelative: false
            }),
            maxLiquidationBonus: IRiskSteward.RiskParamConfig({
              minDelay: 36 hours,
              maxPercentChange: 50,
              isChangeRelative: false
            })
          }),
          liquidation: IRiskSteward.SpokeLiquidationConfig({
            targetHealthFactor: IRiskSteward.RiskParamConfig({
              minDelay: 36 hours,
              maxPercentChange: 5_00,
              isChangeRelative: true
            }),
            healthFactorForMaxBonus: IRiskSteward.RiskParamConfig({
              minDelay: 36 hours,
              maxPercentChange: 5_00,
              isChangeRelative: true
            }),
            liquidationBonusFactor: IRiskSteward.RiskParamConfig({
              minDelay: 36 hours,
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
}
