// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
  AaveV4Ethereum,
  AaveV4EthereumAssets,
  AaveV4EthereumHubs,
  AaveV4EthereumSpokes
} from 'aave-address-book/AaveV4Ethereum.sol';
import {IAaveV4ConfigEngine as IEngine} from 'aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {EngineFlags} from 'aave-v4/config-engine/libraries/EngineFlags.sol';
import {IAssetInterestRateStrategy} from 'aave-v4/hub/interfaces/IAssetInterestRateStrategy.sol';
import {ISpoke} from 'aave-v4/spoke/interfaces/ISpoke.sol';

import {RiskStewardsEthereum} from '../networks/RiskStewardsEthereum.s.sol';

// make run-script network=mainnet contract=scripts/examples/EthereumExample.sol:EthereumExample broadcast=false generate_diff=true skip_timelock=true
/// @title EthereumExample
/// @author Aave Labs
/// @notice Reference payload showing how to author updates for each of the six RiskSteward
/// entrypoints.
contract EthereumExample is RiskStewardsEthereum {
  function name() public pure override returns (string memory) {
    return 'ethereum_example';
  }

  function hubAssetIrUpdates() public pure override returns (IEngine.AssetConfigUpdate[] memory) {
    IEngine.AssetConfigUpdate[] memory updates = new IEngine.AssetConfigUpdate[](2);
    updates[0] = IEngine.AssetConfigUpdate({
      hubConfigurator: AaveV4Ethereum.HUB_CONFIGURATOR,
      hub: address(AaveV4EthereumHubs.CORE_HUB),
      underlying: AaveV4EthereumAssets.WETH_UNDERLYING,
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
      hubConfigurator: AaveV4Ethereum.HUB_CONFIGURATOR,
      hub: address(AaveV4EthereumHubs.PLUS_HUB),
      underlying: AaveV4EthereumAssets.USDC_UNDERLYING,
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
      hubConfigurator: AaveV4Ethereum.HUB_CONFIGURATOR,
      hub: address(AaveV4EthereumHubs.CORE_HUB),
      underlying: AaveV4EthereumAssets.WETH_UNDERLYING,
      spoke: address(AaveV4EthereumSpokes.MAIN_SPOKE),
      addCap: 1_000_000 ether,
      drawCap: 800_000 ether,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });
    updates[1] = IEngine.SpokeConfigUpdate({
      hubConfigurator: AaveV4Ethereum.HUB_CONFIGURATOR,
      hub: address(AaveV4EthereumHubs.PLUS_HUB),
      underlying: AaveV4EthereumAssets.USDC_UNDERLYING,
      spoke: address(AaveV4EthereumSpokes.MAIN_SPOKE),
      addCap: 50_000_000_000_000,
      drawCap: 40_000_000_000_000,
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
    IEngine.ReserveConfigUpdate[] memory updates = new IEngine.ReserveConfigUpdate[](2);
    updates[0] = IEngine.ReserveConfigUpdate({
      spokeConfigurator: AaveV4Ethereum.SPOKE_CONFIGURATOR,
      spoke: address(AaveV4EthereumSpokes.MAIN_SPOKE),
      hub: address(AaveV4EthereumHubs.CORE_HUB),
      underlying: AaveV4EthereumAssets.WETH_UNDERLYING,
      priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
      collateralRisk: 1_500,
      paused: EngineFlags.KEEP_CURRENT,
      frozen: EngineFlags.KEEP_CURRENT,
      borrowable: EngineFlags.KEEP_CURRENT,
      receiveSharesEnabled: EngineFlags.KEEP_CURRENT
    });
    updates[1] = IEngine.ReserveConfigUpdate({
      spokeConfigurator: AaveV4Ethereum.SPOKE_CONFIGURATOR,
      spoke: address(AaveV4EthereumSpokes.LIDO_ESPOKE),
      hub: address(AaveV4EthereumHubs.CORE_HUB),
      underlying: AaveV4EthereumAssets.wstETH_UNDERLYING,
      priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
      collateralRisk: 1_800,
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
      2
    );
    updates[0] = IEngine.DynamicReserveConfigUpdate({
      spokeConfigurator: AaveV4Ethereum.SPOKE_CONFIGURATOR,
      spoke: address(AaveV4EthereumSpokes.MAIN_SPOKE),
      hub: address(AaveV4EthereumHubs.CORE_HUB),
      underlying: AaveV4EthereumAssets.WETH_UNDERLYING,
      dynamicConfigKey: 0,
      collateralFactor: 80_00,
      maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
      liquidationFee: EngineFlags.KEEP_CURRENT
    });
    updates[1] = IEngine.DynamicReserveConfigUpdate({
      spokeConfigurator: AaveV4Ethereum.SPOKE_CONFIGURATOR,
      spoke: address(AaveV4EthereumSpokes.MAIN_SPOKE),
      hub: address(AaveV4EthereumHubs.CORE_HUB),
      underlying: AaveV4EthereumAssets.WETH_UNDERLYING,
      dynamicConfigKey: 1,
      collateralFactor: 82_00,
      maxLiquidationBonus: 6_00,
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
      memory additions = new IEngine.DynamicReserveConfigAddition[](2);
    additions[0] = IEngine.DynamicReserveConfigAddition({
      spokeConfigurator: AaveV4Ethereum.SPOKE_CONFIGURATOR,
      spoke: address(AaveV4EthereumSpokes.MAIN_SPOKE),
      hub: address(AaveV4EthereumHubs.CORE_HUB),
      underlying: AaveV4EthereumAssets.WETH_UNDERLYING,
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 82_00,
        maxLiquidationBonus: 5_00,
        liquidationFee: 10_00
      })
    });
    additions[1] = IEngine.DynamicReserveConfigAddition({
      spokeConfigurator: AaveV4Ethereum.SPOKE_CONFIGURATOR,
      spoke: address(AaveV4EthereumSpokes.LIDO_ESPOKE),
      hub: address(AaveV4EthereumHubs.CORE_HUB),
      underlying: AaveV4EthereumAssets.wstETH_UNDERLYING,
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 6_00,
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
    IEngine.LiquidationConfigUpdate[] memory updates = new IEngine.LiquidationConfigUpdate[](2);
    updates[0] = IEngine.LiquidationConfigUpdate({
      spokeConfigurator: AaveV4Ethereum.SPOKE_CONFIGURATOR,
      spoke: address(AaveV4EthereumSpokes.MAIN_SPOKE),
      targetHealthFactor: 1.05e18,
      healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
      liquidationBonusFactor: EngineFlags.KEEP_CURRENT
    });
    updates[1] = IEngine.LiquidationConfigUpdate({
      spokeConfigurator: AaveV4Ethereum.SPOKE_CONFIGURATOR,
      spoke: address(AaveV4EthereumSpokes.LIDO_ESPOKE),
      targetHealthFactor: EngineFlags.KEEP_CURRENT,
      healthFactorForMaxBonus: 1.01e18,
      liquidationBonusFactor: 5_00
    });
    return updates;
  }
}
