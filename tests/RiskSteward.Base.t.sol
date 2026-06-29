// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {Ownable2Step, Ownable} from 'aave-v4/dependencies/openzeppelin/Ownable2Step.sol';
import {SafeCast} from 'aave-v4/dependencies/openzeppelin/SafeCast.sol';

import {
  AaveV4Ethereum,
  AaveV4EthereumHubs,
  AaveV4EthereumSpokes,
  AaveV4EthereumAssets
} from 'aave-address-book/AaveV4Ethereum.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {EngineFlags} from 'aave-v4/config-engine/libraries/EngineFlags.sol';
import {Roles} from 'aave-v4/deployments/utils/libraries/Roles.sol';
import {PercentageMath} from 'aave-v4/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'aave-v4/libraries/math/WadRayMath.sol';

import {IAaveV4ConfigEngine as IEngine} from 'aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IHub} from 'aave-v4/hub/interfaces/IHub.sol';
import {IHubBase} from 'aave-v4/hub/interfaces/IHubBase.sol';
import {IHubConfigurator} from 'aave-v4/hub/interfaces/IHubConfigurator.sol';
import {IAssetInterestRateStrategy} from 'aave-v4/hub/interfaces/IAssetInterestRateStrategy.sol';
import {ISpoke} from 'aave-v4/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'aave-v4/spoke/interfaces/ISpokeConfigurator.sol';
import {IAccessManagerEnumerable} from 'aave-v4/access/interfaces/IAccessManagerEnumerable.sol';

import {IPriceCapAdapter} from 'aave-price-feeds/interfaces/IPriceCapAdapter.sol';
import {IPriceCapAdapterStable} from 'aave-price-feeds/interfaces/IPriceCapAdapterStable.sol';
import {IPendlePriceCapAdapter} from 'aave-price-feeds/interfaces/IPendlePriceCapAdapter.sol';

import {RiskSteward, IRiskSteward} from 'src/RiskSteward.sol';

contract RiskStewardTestBase is Test {
  using SafeCast for *;

  address internal immutable RISK_COUNCIL = makeAddr('RISK_COUNCIL');

  address internal constant OWNER = GovernanceV3Ethereum.EXECUTOR_LVL_1;
  IHub internal constant HUB = AaveV4EthereumHubs.CORE_HUB;
  ISpoke internal constant MAIN_SPOKE = AaveV4EthereumSpokes.MAIN_SPOKE;
  ISpoke internal constant LIDO_SPOKE = AaveV4EthereumSpokes.LIDO_ESPOKE;
  IHubConfigurator internal constant HUB_CONFIGURATOR = AaveV4Ethereum.HUB_CONFIGURATOR;
  ISpokeConfigurator internal constant SPOKE_CONFIGURATOR = AaveV4Ethereum.SPOKE_CONFIGURATOR;
  IAccessManagerEnumerable internal constant ACCESS_MANAGER = AaveV4Ethereum.ACCESS_MANAGER;
  address internal constant ASSET = AaveV4EthereumAssets.WETH_UNDERLYING;

  RiskSteward internal steward;

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 25171813);

    steward = new RiskSteward(RISK_COUNCIL, OWNER);

    vm.startPrank(OWNER);
    steward.setHubConfig(address(HUB), _defaultHubConfig());
    steward.setSpokeConfig(address(MAIN_SPOKE), _defaultSpokeConfig());
    steward.setSpokeConfig(address(LIDO_SPOKE), _defaultSpokeConfig());
    steward.setPriceCapConfig(_defaultPriceCapConfig());
    vm.stopPrank();

    address defaultAdmin = ACCESS_MANAGER.getRoleMember(Roles.ACCESS_MANAGER_ADMIN_ROLE, 0);
    vm.startPrank(defaultAdmin);
    ACCESS_MANAGER.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(steward), 0);
    ACCESS_MANAGER.grantRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(steward), 0);
    vm.stopPrank();

    _label();
  }

  function _label() internal {
    vm.label(OWNER, 'EXECUTOR_LVL_1');
    vm.label(address(HUB), 'CORE_HUB');
    vm.label(address(MAIN_SPOKE), 'MAIN_SPOKE');
    vm.label(address(LIDO_SPOKE), 'LIDO_SPOKE');
    vm.label(address(HUB_CONFIGURATOR), 'HUB_CONFIGURATOR');
    vm.label(address(SPOKE_CONFIGURATOR), 'SPOKE_CONFIGURATOR');
    vm.label(ASSET, 'WETH');
  }

  function _defaultHubConfig() internal pure returns (IRiskSteward.HubConfig memory) {
    return
      IRiskSteward.HubConfig({
        hubConfigurator: HUB_CONFIGURATOR,
        rate: IRiskSteward.HubRateConfig({
          optimalUsageRatio: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 3_00,
            isChangeRelative: false
          }),
          baseDrawnRate: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 1_00,
            isChangeRelative: false
          }),
          rateGrowthBeforeOptimal: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 1_00,
            isChangeRelative: false
          }),
          rateGrowthAfterOptimal: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 20_00,
            isChangeRelative: false
          })
        }),
        cap: IRiskSteward.HubCapConfig({
          addCap: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 100_00,
            isChangeRelative: true
          }),
          drawCap: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 100_00,
            isChangeRelative: true
          })
        })
      });
  }

  function _defaultSpokeConfig() internal pure returns (IRiskSteward.SpokeConfig memory) {
    return
      IRiskSteward.SpokeConfig({
        spokeConfigurator: SPOKE_CONFIGURATOR,
        collateralRisk: IRiskSteward.RiskParamConfig({
          minDelay: 3 days,
          maxPercentChange: 20_00,
          isChangeRelative: false
        }),
        dynamicUpdate: IRiskSteward.SpokeDynamicConfig({
          collateralFactor: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 50,
            isChangeRelative: false
          }),
          maxLiquidationBonus: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 50,
            isChangeRelative: false
          })
        }),
        dynamicAdd: IRiskSteward.SpokeDynamicConfig({
          collateralFactor: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 5_00,
            isChangeRelative: false
          }),
          maxLiquidationBonus: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 5_00,
            isChangeRelative: false
          })
        }),
        liquidation: IRiskSteward.SpokeLiquidationConfig({
          targetHealthFactor: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 5_00,
            isChangeRelative: true
          }),
          healthFactorForMaxBonus: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 5_00,
            isChangeRelative: true
          }),
          liquidationBonusFactor: IRiskSteward.RiskParamConfig({
            minDelay: 3 days,
            maxPercentChange: 5_00,
            isChangeRelative: false
          })
        })
      });
  }

  function _defaultPriceCapConfig() internal pure returns (IRiskSteward.PriceCapConfig memory) {
    return
      IRiskSteward.PriceCapConfig({
        priceCapLst: IRiskSteward.RiskParamConfig({
          minDelay: 3 days,
          maxPercentChange: 10_00,
          isChangeRelative: true
        }),
        priceCapStable: IRiskSteward.RiskParamConfig({
          minDelay: 3 days,
          maxPercentChange: 5_00,
          isChangeRelative: true
        }),
        discountRatePendle: IRiskSteward.RiskParamConfig({
          minDelay: 3 days,
          maxPercentChange: 0.1e18,
          isChangeRelative: false
        })
      });
  }

  function _interestRateData(
    IHub hub,
    address underlying
  ) internal view returns (IAssetInterestRateStrategy.InterestRateData memory) {
    uint256 assetId = hub.getAssetId(underlying);
    address irStrategy = hub.getAssetConfig(assetId).irStrategy;
    return IAssetInterestRateStrategy(irStrategy).getInterestRateData(assetId);
  }

  function _spokeConfig(
    IHub hub,
    ISpoke spoke,
    address underlying
  ) internal view returns (IHub.SpokeConfig memory) {
    uint256 assetId = hub.getAssetId(underlying);
    return hub.getSpokeConfig(assetId, address(spoke));
  }

  function _reserveConfig(
    ISpoke spoke,
    IHub hub,
    address underlying
  ) internal view returns (ISpoke.ReserveConfig memory) {
    uint256 assetId = hub.getAssetId(underlying);
    uint256 reserveId = spoke.getReserveId(address(hub), assetId);
    return spoke.getReserveConfig(reserveId);
  }

  function _dynamicReserveConfig(
    ISpoke spoke,
    IHub hub,
    address underlying
  ) internal view returns (ISpoke.DynamicReserveConfig memory, uint32) {
    uint256 assetId = hub.getAssetId(underlying);
    uint256 reserveId = spoke.getReserveId(address(hub), assetId);
    uint32 latestKey = spoke.getReserve(reserveId).dynamicConfigKey;
    return (spoke.getDynamicReserveConfig(reserveId, latestKey), latestKey);
  }

  function _baseIRUpdate() internal pure returns (IEngine.AssetConfigUpdate memory) {
    return
      IEngine.AssetConfigUpdate({
        hubConfigurator: HUB_CONFIGURATOR,
        hub: address(HUB),
        underlying: ASSET,
        liquidityFee: EngineFlags.KEEP_CURRENT,
        feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
        irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
        irData: IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: EngineFlags.KEEP_CURRENT_UINT16,
          baseDrawnRate: EngineFlags.KEEP_CURRENT_UINT32,
          rateGrowthBeforeOptimal: EngineFlags.KEEP_CURRENT_UINT32,
          rateGrowthAfterOptimal: EngineFlags.KEEP_CURRENT_UINT32
        }),
        reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
      });
  }

  function _baseSpokeCapsUpdate() internal pure returns (IEngine.SpokeConfigUpdate memory) {
    return
      IEngine.SpokeConfigUpdate({
        hubConfigurator: HUB_CONFIGURATOR,
        hub: address(HUB),
        underlying: ASSET,
        spoke: address(MAIN_SPOKE),
        addCap: EngineFlags.KEEP_CURRENT,
        drawCap: EngineFlags.KEEP_CURRENT,
        riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
        active: EngineFlags.KEEP_CURRENT,
        halted: EngineFlags.KEEP_CURRENT
      });
  }

  function _baseReserveUpdate() internal pure returns (IEngine.ReserveConfigUpdate memory) {
    return
      IEngine.ReserveConfigUpdate({
        spokeConfigurator: SPOKE_CONFIGURATOR,
        spoke: address(MAIN_SPOKE),
        hub: address(HUB),
        underlying: ASSET,
        priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
        collateralRisk: EngineFlags.KEEP_CURRENT,
        paused: EngineFlags.KEEP_CURRENT,
        frozen: EngineFlags.KEEP_CURRENT,
        borrowable: EngineFlags.KEEP_CURRENT,
        receiveSharesEnabled: EngineFlags.KEEP_CURRENT
      });
  }

  function _baseDynamicUpdate() internal view returns (IEngine.DynamicReserveConfigUpdate memory) {
    (, uint32 latestKey) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    return
      IEngine.DynamicReserveConfigUpdate({
        spokeConfigurator: SPOKE_CONFIGURATOR,
        spoke: address(MAIN_SPOKE),
        hub: address(HUB),
        underlying: ASSET,
        dynamicConfigKey: latestKey,
        collateralFactor: EngineFlags.KEEP_CURRENT,
        maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
        liquidationFee: EngineFlags.KEEP_CURRENT
      });
  }

  function _baseAddDynamic() internal view returns (IEngine.DynamicReserveConfigAddition memory) {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    return
      IEngine.DynamicReserveConfigAddition({
        spokeConfigurator: SPOKE_CONFIGURATOR,
        spoke: address(MAIN_SPOKE),
        hub: address(HUB),
        underlying: ASSET,
        dynamicConfig: ISpoke.DynamicReserveConfig({
          collateralFactor: ref.collateralFactor,
          maxLiquidationBonus: ref.maxLiquidationBonus,
          liquidationFee: ref.liquidationFee
        })
      });
  }

  function _baseLiquidationUpdate() internal pure returns (IEngine.LiquidationConfigUpdate memory) {
    return
      IEngine.LiquidationConfigUpdate({
        spokeConfigurator: SPOKE_CONFIGURATOR,
        spoke: address(MAIN_SPOKE),
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });
  }

  /// @dev Applies a signed `delta` to `current`, clamping the result into `[floor, ceiling]`.
  function _applyDelta(
    uint256 current,
    int256 delta,
    uint256 floor,
    uint256 ceiling
  ) internal pure returns (uint256) {
    int256 result = current.toInt256() + delta;
    if (result < floor.toInt256()) return floor;
    if (result.toUint256() > ceiling) return ceiling;
    return result.toUint256();
  }

  function _applyDelta(
    uint256 current,
    int256 delta,
    uint256 floor
  ) internal pure returns (uint256) {
    return _applyDelta(current, delta, floor, type(uint256).max);
  }

  /// @dev Same as `_applyDelta` but interprets `deltaBps` as a BPS-of-current relative change.
  function _applyRelativeDelta(
    uint256 current,
    int256 deltaBps,
    uint256 floor,
    uint256 ceiling
  ) internal pure returns (uint256) {
    int256 result = current.toInt256() + (current.toInt256() * deltaBps) / 100_00;
    if (result < floor.toInt256()) return floor;
    if (result.toUint256() > ceiling) return ceiling;
    return result.toUint256();
  }

  function _applyRelativeDelta(
    uint256 current,
    int256 deltaBps,
    uint256 floor
  ) internal pure returns (uint256) {
    return _applyRelativeDelta(current, deltaBps, floor, type(uint256).max);
  }

  /// @dev Bounds a signed fuzz delta to `[-maxAbs, +maxAbs]` where `maxAbs` is read from a steward
  /// `RiskParamConfig.maxPercentChange` (BPS for absolute fields, or BPS-of-current for relative).
  function _boundDelta(int256 delta, uint256 maxAbs) internal pure returns (int256) {
    int256 maxSigned = maxAbs.toInt256();
    return bound(delta, -maxSigned, maxSigned);
  }

  function _toArray(
    IEngine.AssetConfigUpdate memory update
  ) internal pure returns (IEngine.AssetConfigUpdate[] memory) {
    IEngine.AssetConfigUpdate[] memory arr = new IEngine.AssetConfigUpdate[](1);
    arr[0] = update;
    return arr;
  }

  function _toArray(
    IEngine.SpokeConfigUpdate memory update
  ) internal pure returns (IEngine.SpokeConfigUpdate[] memory) {
    IEngine.SpokeConfigUpdate[] memory arr = new IEngine.SpokeConfigUpdate[](1);
    arr[0] = update;
    return arr;
  }

  function _toArray(
    IEngine.ReserveConfigUpdate memory update
  ) internal pure returns (IEngine.ReserveConfigUpdate[] memory) {
    IEngine.ReserveConfigUpdate[] memory arr = new IEngine.ReserveConfigUpdate[](1);
    arr[0] = update;
    return arr;
  }

  function _toArray(
    IEngine.DynamicReserveConfigUpdate memory update
  ) internal pure returns (IEngine.DynamicReserveConfigUpdate[] memory) {
    IEngine.DynamicReserveConfigUpdate[] memory arr = new IEngine.DynamicReserveConfigUpdate[](1);
    arr[0] = update;
    return arr;
  }

  function _toArray(
    IEngine.DynamicReserveConfigAddition memory update
  ) internal pure returns (IEngine.DynamicReserveConfigAddition[] memory) {
    IEngine.DynamicReserveConfigAddition[] memory arr = new IEngine.DynamicReserveConfigAddition[](
      1
    );
    arr[0] = update;
    return arr;
  }

  function _toArray(
    IEngine.LiquidationConfigUpdate memory update
  ) internal pure returns (IEngine.LiquidationConfigUpdate[] memory) {
    IEngine.LiquidationConfigUpdate[] memory arr = new IEngine.LiquidationConfigUpdate[](1);
    arr[0] = update;
    return arr;
  }

  function _toArray(
    IRiskSteward.PriceCapLstUpdate memory update
  ) internal pure returns (IRiskSteward.PriceCapLstUpdate[] memory) {
    IRiskSteward.PriceCapLstUpdate[] memory arr = new IRiskSteward.PriceCapLstUpdate[](1);
    arr[0] = update;
    return arr;
  }

  function _toArray(
    IRiskSteward.PriceCapStableUpdate memory update
  ) internal pure returns (IRiskSteward.PriceCapStableUpdate[] memory) {
    IRiskSteward.PriceCapStableUpdate[] memory arr = new IRiskSteward.PriceCapStableUpdate[](1);
    arr[0] = update;
    return arr;
  }

  function _toArray(
    IRiskSteward.DiscountRatePendleUpdate memory update
  ) internal pure returns (IRiskSteward.DiscountRatePendleUpdate[] memory) {
    IRiskSteward.DiscountRatePendleUpdate[]
      memory arr = new IRiskSteward.DiscountRatePendleUpdate[](1);
    arr[0] = update;
    return arr;
  }

  function assertEq(
    IAssetInterestRateStrategy.InterestRateData memory a,
    IAssetInterestRateStrategy.InterestRateData memory b
  ) internal pure {
    assertEq(a.optimalUsageRatio, b.optimalUsageRatio);
    assertEq(a.baseDrawnRate, b.baseDrawnRate);
    assertEq(a.rateGrowthBeforeOptimal, b.rateGrowthBeforeOptimal);
    assertEq(a.rateGrowthAfterOptimal, b.rateGrowthAfterOptimal);
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(IHub.SpokeConfig memory a, IHub.SpokeConfig memory b) internal pure {
    assertEq(a.addCap, b.addCap);
    assertEq(a.drawCap, b.drawCap);
    assertEq(a.riskPremiumThreshold, b.riskPremiumThreshold);
    assertEq(a.active, b.active);
    assertEq(a.halted, b.halted);
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(ISpoke.ReserveConfig memory a, ISpoke.ReserveConfig memory b) internal pure {
    assertEq(a.collateralRisk, b.collateralRisk);
    assertEq(a.paused, b.paused);
    assertEq(a.frozen, b.frozen);
    assertEq(a.borrowable, b.borrowable);
    assertEq(a.receiveSharesEnabled, b.receiveSharesEnabled);
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(
    ISpoke.DynamicReserveConfig memory a,
    ISpoke.DynamicReserveConfig memory b
  ) internal pure {
    assertEq(a.collateralFactor, b.collateralFactor);
    assertEq(a.maxLiquidationBonus, b.maxLiquidationBonus);
    assertEq(a.liquidationFee, b.liquidationFee);
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(
    ISpoke.LiquidationConfig memory a,
    ISpoke.LiquidationConfig memory b
  ) internal pure {
    assertEq(a.targetHealthFactor, b.targetHealthFactor);
    assertEq(a.healthFactorForMaxBonus, b.healthFactorForMaxBonus);
    assertEq(a.liquidationBonusFactor, b.liquidationBonusFactor);
    assertEq(abi.encode(a), abi.encode(b));
  }

  function assertEq(
    IPriceCapAdapter adapter,
    IRiskSteward.PriceCapLstUpdate memory expected
  ) internal view {
    assertEq(adapter.getSnapshotRatio(), expected.priceCapUpdateParams.snapshotRatio);
    assertEq(adapter.getSnapshotTimestamp(), expected.priceCapUpdateParams.snapshotTimestamp);
    assertEq(
      adapter.getMaxYearlyGrowthRatePercent(),
      expected.priceCapUpdateParams.maxYearlyRatioGrowthPercent
    );
  }

  function assertEq(
    IPriceCapAdapterStable adapter,
    IRiskSteward.PriceCapStableUpdate memory expected
  ) internal view {
    assertEq(adapter.getPriceCap(), expected.priceCap.toInt256());
  }

  function assertEq(
    IPendlePriceCapAdapter adapter,
    IRiskSteward.DiscountRatePendleUpdate memory expected
  ) internal view {
    assertEq(adapter.discountRatePerYear(), expected.discountRate);
  }
}
