// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
  AaveV4Base,
  AaveV4BaseAssets,
  AaveV4BaseHubs,
  AaveV4BaseSpokes
} from 'aave-address-book/AaveV4Base.sol';
import {IAaveV4ConfigEngine as IEngine} from 'aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {EngineFlags} from 'aave-v4/config-engine/libraries/EngineFlags.sol';
import {IAssetInterestRateStrategy} from 'aave-v4/hub/interfaces/IAssetInterestRateStrategy.sol';
import {ISpoke} from 'aave-v4/spoke/interfaces/ISpoke.sol';

import {RiskStewardsBaseChain} from '../networks/RiskStewardsBaseChain.s.sol';

// make run-script network=base contract=scripts/examples/BaseExample.sol:BaseExample broadcast=false generate_diff=true skip_timelock=true
/// @title BaseExample
/// @author Aave Labs
/// @notice Reference payload showing how to author updates for each of the six RiskSteward
/// entrypoints on the Base equities market.
/// @dev The seven B20 equities are node-native tokens the stock EVM cannot execute, so a diff
/// report generated here only carries real asset symbols under base-anvil's forge. See the
/// `test-base` CI job.
contract BaseExample is RiskStewardsBaseChain {
  function name() public pure override returns (string memory) {
    return 'base_example';
  }

  function hubAssetIrUpdates() public pure override returns (IEngine.AssetConfigUpdate[] memory) {
    IEngine.AssetConfigUpdate[] memory updates = new IEngine.AssetConfigUpdate[](2);
    updates[0] = IEngine.AssetConfigUpdate({
      hubConfigurator: AaveV4Base.HUB_CONFIGURATOR,
      hub: address(AaveV4BaseHubs.EQUITIES_HUB),
      underlying: AaveV4BaseAssets.AAPLc_UNDERLYING,
      liquidityFee: EngineFlags.KEEP_CURRENT,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: EngineFlags.KEEP_CURRENT_UINT16,
        baseDrawnRate: 1_00,
        rateGrowthBeforeOptimal: EngineFlags.KEEP_CURRENT_UINT32,
        rateGrowthAfterOptimal: EngineFlags.KEEP_CURRENT_UINT32
      }),
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    updates[1] = IEngine.AssetConfigUpdate({
      hubConfigurator: AaveV4Base.HUB_CONFIGURATOR,
      hub: address(AaveV4BaseHubs.EQUITIES_HUB),
      underlying: AaveV4BaseAssets.USDC_UNDERLYING,
      liquidityFee: EngineFlags.KEEP_CURRENT,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00,
        baseDrawnRate: EngineFlags.KEEP_CURRENT_UINT32,
        rateGrowthBeforeOptimal: EngineFlags.KEEP_CURRENT_UINT32,
        rateGrowthAfterOptimal: EngineFlags.KEEP_CURRENT_UINT32
      }),
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    return updates;
  }

  function hubSpokeCapsUpdates() public pure override returns (IEngine.SpokeConfigUpdate[] memory) {
    IEngine.SpokeConfigUpdate[] memory updates = new IEngine.SpokeConfigUpdate[](2);
    updates[0] = IEngine.SpokeConfigUpdate({
      hubConfigurator: AaveV4Base.HUB_CONFIGURATOR,
      hub: address(AaveV4BaseHubs.EQUITIES_HUB),
      underlying: AaveV4BaseAssets.AAPLc_UNDERLYING,
      spoke: address(AaveV4BaseSpokes.MAG7_SPOKE),
      addCap: 16_500,
      drawCap: EngineFlags.KEEP_CURRENT,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });
    updates[1] = IEngine.SpokeConfigUpdate({
      hubConfigurator: AaveV4Base.HUB_CONFIGURATOR,
      hub: address(AaveV4BaseHubs.EQUITIES_HUB),
      underlying: AaveV4BaseAssets.USDC_UNDERLYING,
      spoke: address(AaveV4BaseSpokes.MAG7_SPOKE),
      addCap: 35_200_000,
      drawCap: 23_100_000,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });
    return updates;
  }

  function reserveConfigUpdates()
    public
    pure
    override
    returns (IEngine.ReserveConfigUpdate[] memory)
  {
    IEngine.ReserveConfigUpdate[] memory updates = new IEngine.ReserveConfigUpdate[](1);
    updates[0] = IEngine.ReserveConfigUpdate({
      spokeConfigurator: AaveV4Base.SPOKE_CONFIGURATOR,
      spoke: address(AaveV4BaseSpokes.MAG7_SPOKE),
      hub: address(AaveV4BaseHubs.EQUITIES_HUB),
      underlying: AaveV4BaseAssets.AAPLc_UNDERLYING,
      priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
      collateralRisk: 1_500,
      paused: EngineFlags.KEEP_CURRENT,
      frozen: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.KEEP_CURRENT,
      receiveSharesEnabled: EngineFlags.KEEP_CURRENT
    });
    return updates;
  }

  function dynamicReserveConfigUpdates()
    public
    pure
    override
    returns (IEngine.DynamicReserveConfigUpdate[] memory)
  {
    IEngine.DynamicReserveConfigUpdate[] memory updates = new IEngine.DynamicReserveConfigUpdate[](
      1
    );
    updates[0] = IEngine.DynamicReserveConfigUpdate({
      spokeConfigurator: AaveV4Base.SPOKE_CONFIGURATOR,
      spoke: address(AaveV4BaseSpokes.MAG7_SPOKE),
      hub: address(AaveV4BaseHubs.EQUITIES_HUB),
      underlying: AaveV4BaseAssets.AAPLc_UNDERLYING,
      dynamicConfigKey: 0,
      collateralFactor: 70_00,
      maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
      liquidationFee: EngineFlags.KEEP_CURRENT
    });
    return updates;
  }

  function dynamicReserveConfigAdditions()
    public
    pure
    override
    returns (IEngine.DynamicReserveConfigAddition[] memory)
  {
    IEngine.DynamicReserveConfigAddition[]
      memory additions = new IEngine.DynamicReserveConfigAddition[](1);
    additions[0] = IEngine.DynamicReserveConfigAddition({
      spokeConfigurator: AaveV4Base.SPOKE_CONFIGURATOR,
      spoke: address(AaveV4BaseSpokes.MAG7_SPOKE),
      hub: address(AaveV4BaseHubs.EQUITIES_HUB),
      underlying: AaveV4BaseAssets.AAPLc_UNDERLYING,
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 72_00,
        maxLiquidationBonus: 10_00,
        liquidationFee: 10_00
      })
    });
    return additions;
  }

  function spokeLiquidationConfigUpdates()
    public
    pure
    override
    returns (IEngine.LiquidationConfigUpdate[] memory)
  {
    IEngine.LiquidationConfigUpdate[] memory updates = new IEngine.LiquidationConfigUpdate[](1);
    updates[0] = IEngine.LiquidationConfigUpdate({
      spokeConfigurator: AaveV4Base.SPOKE_CONFIGURATOR,
      spoke: address(AaveV4BaseSpokes.MAG7_SPOKE),
      targetHealthFactor: 1.2e18,
      healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
      liquidationBonusFactor: EngineFlags.KEEP_CURRENT
    });
    return updates;
  }
}
