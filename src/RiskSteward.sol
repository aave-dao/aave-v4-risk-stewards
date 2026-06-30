// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable2Step, Ownable} from 'aave-v4/dependencies/openzeppelin/Ownable2Step.sol';
import {SafeCast} from 'aave-v4/dependencies/openzeppelin/SafeCast.sol';

import {EngineFlags} from 'aave-v4/config-engine/libraries/EngineFlags.sol';
import {HubEngine} from 'aave-v4/config-engine/libraries/HubEngine.sol';
import {SpokeEngine} from 'aave-v4/config-engine/libraries/SpokeEngine.sol';
import {PercentageMath} from 'aave-v4/libraries/math/PercentageMath.sol';

import {IAaveV4ConfigEngine as IEngine} from 'aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IHub} from 'aave-v4/hub/interfaces/IHub.sol';
import {IAssetInterestRateStrategy} from 'aave-v4/hub/interfaces/IAssetInterestRateStrategy.sol';
import {ISpoke} from 'aave-v4/spoke/interfaces/ISpoke.sol';
import {IPriceCapAdapter} from 'aave-price-feeds/interfaces/IPriceCapAdapter.sol';
import {IPriceCapAdapterStable} from 'aave-price-feeds/interfaces/IPriceCapAdapterStable.sol';
import {IPendlePriceCapAdapter} from 'aave-price-feeds/interfaces/IPendlePriceCapAdapter.sol';

import {IRiskSteward} from 'src/interfaces/IRiskSteward.sol';

/// @title RiskSteward
/// @author Aave Labs
/// @notice Manages risk param updates within owner-configured bounds across Aave v4 Hubs and
/// Spokes. Risk Council is the only address allowed to invoke update entrypoints; each param
/// has its own debounce timestamp and configured max allowed change.
contract RiskSteward is Ownable2Step, IRiskSteward {
  using SafeCast for *;
  using PercentageMath for uint256;
  using HubEngine for *;
  using SpokeEngine for *;

  /// @inheritdoc IRiskSteward
  address public immutable RISK_COUNCIL;

  Config internal _config;

  mapping(IHub hub => mapping(address asset => HubAssetDebounce)) internal _hubAssetDebounces;
  mapping(IHub hub => mapping(ISpoke spoke => mapping(address asset => HubSpokeAssetDebounce)))
    internal _hubSpokeAssetDebounces;
  mapping(ISpoke spoke => mapping(IHub hub => mapping(address asset => SpokeReserveDebounce)))
    internal _spokeReserveDebounces;
  mapping(ISpoke spoke => mapping(IHub hub => mapping(address asset => SpokeDynamicDebounce)))
    internal _spokeDynamicDebounces;
  mapping(ISpoke spoke => SpokeLiquidationDebounce) internal _spokeLiquidationDebounces;
  mapping(address oracle => uint40 lastUpdated) internal _oracleDebounces;

  mapping(IHub hub => bool) internal _restrictedHubs;
  mapping(ISpoke spoke => bool) internal _restrictedSpokes;
  mapping(ISpoke spoke => mapping(IHub hub => bool)) internal _restrictedSpokeHubs;
  mapping(ISpoke spoke => mapping(IHub hub => mapping(address asset => bool)))
    internal _restrictedReserves;

  modifier onlyRiskCouncil() {
    require(msg.sender == RISK_COUNCIL, InvalidCaller());
    _;
  }

  /// @dev Constructor.
  /// @param riskCouncil_ The council address authorized to call update entrypoints.
  /// @param initialOwner_ The owner authorized to configure bounds and restrictions.
  constructor(address riskCouncil_, address initialOwner_) Ownable(initialOwner_) {
    require(riskCouncil_ != address(0));
    RISK_COUNCIL = riskCouncil_;
  }

  /// @inheritdoc IRiskSteward
  function setConfig(Config calldata config) external onlyOwner {
    _validateConfig(config);
    _config = config;
    emit ConfigSet(config);
  }

  /// @inheritdoc IRiskSteward
  function setHubRestricted(address hub, bool isRestricted) external onlyOwner {
    _restrictedHubs[IHub(hub)] = isRestricted;
    emit HubRestrictionUpdated(hub, isRestricted);
  }

  /// @inheritdoc IRiskSteward
  function setSpokeRestricted(address spoke, bool isRestricted) external onlyOwner {
    _restrictedSpokes[ISpoke(spoke)] = isRestricted;
    emit SpokeRestrictionUpdated(spoke, isRestricted);
  }

  /// @inheritdoc IRiskSteward
  function setSpokeHubRestricted(address spoke, address hub, bool isRestricted) external onlyOwner {
    _restrictedSpokeHubs[ISpoke(spoke)][IHub(hub)] = isRestricted;
    emit SpokeHubRestrictionUpdated(spoke, hub, isRestricted);
  }

  /// @inheritdoc IRiskSteward
  function setReserveRestricted(
    address spoke,
    address hub,
    address asset,
    bool isRestricted
  ) external onlyOwner {
    _restrictedReserves[ISpoke(spoke)][IHub(hub)][asset] = isRestricted;
    emit ReserveRestrictionUpdated(spoke, hub, asset, isRestricted);
  }

  /// @inheritdoc IRiskSteward
  function updateHubAssetIRs(
    IEngine.AssetConfigUpdate[] calldata updates
  ) external onlyRiskCouncil {
    _validateHubAssetIRs(updates);
    _executeHubAssetIRs(updates);
  }

  /// @inheritdoc IRiskSteward
  function updateHubSpokeCaps(
    IEngine.SpokeConfigUpdate[] calldata updates
  ) external onlyRiskCouncil {
    _validateHubSpokeCaps(updates);
    _executeHubSpokeCaps(updates);
  }

  /// @inheritdoc IRiskSteward
  function updateReserveConfigs(
    IEngine.ReserveConfigUpdate[] calldata updates
  ) external onlyRiskCouncil {
    _validateReserveConfigs(updates);
    _executeReserveConfigs(updates);
  }

  /// @inheritdoc IRiskSteward
  function updateDynamicReserveConfigs(
    IEngine.DynamicReserveConfigUpdate[] calldata updates
  ) external onlyRiskCouncil {
    _validateDynamicReserveConfigs(updates);
    _executeDynamicReserveConfigs(updates);
  }

  /// @inheritdoc IRiskSteward
  function addDynamicReserveConfigs(
    IEngine.DynamicReserveConfigAddition[] calldata additions
  ) external onlyRiskCouncil {
    _validateAddDynamicReserveConfigs(additions);
    _executeAddDynamicReserveConfigs(additions);
  }

  /// @inheritdoc IRiskSteward
  function updateSpokeLiquidationConfigs(
    IEngine.LiquidationConfigUpdate[] calldata updates
  ) external onlyRiskCouncil {
    _validateSpokeLiquidationConfigs(updates);
    _executeSpokeLiquidationConfigs(updates);
  }

  /// @inheritdoc IRiskSteward
  function updateLstPriceCaps(PriceCapLstUpdate[] calldata updates) external onlyRiskCouncil {
    _validateLstPriceCaps(updates);
    _executeLstPriceCaps(updates);
  }

  /// @inheritdoc IRiskSteward
  function updateStablePriceCaps(PriceCapStableUpdate[] calldata updates) external onlyRiskCouncil {
    _validateStablePriceCaps(updates);
    _executeStablePriceCaps(updates);
  }

  /// @inheritdoc IRiskSteward
  function updatePendleDiscountRates(
    DiscountRatePendleUpdate[] calldata updates
  ) external onlyRiskCouncil {
    _validatePendleDiscountRates(updates);
    _executePendleDiscountRates(updates);
  }

  /// @inheritdoc IRiskSteward
  function getConfig() external view returns (Config memory) {
    return _config;
  }

  /// @inheritdoc IRiskSteward
  function getHubAssetDebounce(
    address hub,
    address asset
  ) external view returns (HubAssetDebounce memory) {
    return _hubAssetDebounces[IHub(hub)][asset];
  }

  /// @inheritdoc IRiskSteward
  function getHubSpokeAssetDebounce(
    address hub,
    address spoke,
    address asset
  ) external view returns (HubSpokeAssetDebounce memory) {
    return _hubSpokeAssetDebounces[IHub(hub)][ISpoke(spoke)][asset];
  }

  /// @inheritdoc IRiskSteward
  function getSpokeReserveDebounce(
    address spoke,
    address hub,
    address asset
  ) external view returns (SpokeReserveDebounce memory) {
    return _spokeReserveDebounces[ISpoke(spoke)][IHub(hub)][asset];
  }

  /// @inheritdoc IRiskSteward
  function getSpokeDynamicDebounce(
    address spoke,
    address hub,
    address asset
  ) external view returns (SpokeDynamicDebounce memory) {
    return _spokeDynamicDebounces[ISpoke(spoke)][IHub(hub)][asset];
  }

  /// @inheritdoc IRiskSteward
  function getSpokeLiquidationDebounce(
    address spoke
  ) external view returns (SpokeLiquidationDebounce memory) {
    return _spokeLiquidationDebounces[ISpoke(spoke)];
  }

  /// @inheritdoc IRiskSteward
  function getOracleDebounce(address oracle) external view returns (uint40) {
    return _oracleDebounces[oracle];
  }

  /// @inheritdoc IRiskSteward
  function isHubRestricted(address hub) external view returns (bool) {
    return _restrictedHubs[IHub(hub)];
  }

  /// @inheritdoc IRiskSteward
  function isSpokeRestricted(address spoke) external view returns (bool) {
    return _restrictedSpokes[ISpoke(spoke)];
  }

  /// @inheritdoc IRiskSteward
  function isSpokeHubRestricted(address spoke, address hub) external view returns (bool) {
    return _restrictedSpokeHubs[ISpoke(spoke)][IHub(hub)];
  }

  /// @inheritdoc IRiskSteward
  function isReserveRestricted(
    address spoke,
    address hub,
    address asset
  ) external view returns (bool) {
    return _restrictedReserves[ISpoke(spoke)][IHub(hub)][asset];
  }

  function _executeHubAssetIRs(IEngine.AssetConfigUpdate[] memory updates) internal {
    uint40 currentTime = block.timestamp.toUint40();
    for (uint256 i; i < updates.length; ++i) {
      HubAssetDebounce storage debounce = _hubAssetDebounces[IHub(updates[i].hub)][
        updates[i].underlying
      ];
      if (updates[i].irData.optimalUsageRatio != EngineFlags.KEEP_CURRENT_UINT16) {
        debounce.optimalUsageRatio = currentTime;
      }
      if (updates[i].irData.baseDrawnRate != EngineFlags.KEEP_CURRENT_UINT32) {
        debounce.baseDrawnRate = currentTime;
      }
      if (updates[i].irData.rateGrowthBeforeOptimal != EngineFlags.KEEP_CURRENT_UINT32) {
        debounce.rateGrowthBeforeOptimal = currentTime;
      }
      if (updates[i].irData.rateGrowthAfterOptimal != EngineFlags.KEEP_CURRENT_UINT32) {
        debounce.rateGrowthAfterOptimal = currentTime;
      }
    }
    updates.executeHubAssetConfigUpdates();
  }

  function _executeHubSpokeCaps(IEngine.SpokeConfigUpdate[] memory updates) internal {
    uint40 currentTime = block.timestamp.toUint40();
    for (uint256 i; i < updates.length; ++i) {
      HubSpokeAssetDebounce storage debounce = _hubSpokeAssetDebounces[IHub(updates[i].hub)][
        ISpoke(updates[i].spoke)
      ][updates[i].underlying];
      if (updates[i].addCap != EngineFlags.KEEP_CURRENT) debounce.addCap = currentTime;
      if (updates[i].drawCap != EngineFlags.KEEP_CURRENT) debounce.drawCap = currentTime;
    }
    updates.executeHubSpokeConfigUpdates();
  }

  function _executeReserveConfigs(IEngine.ReserveConfigUpdate[] memory updates) internal {
    uint40 currentTime = block.timestamp.toUint40();
    for (uint256 i; i < updates.length; ++i) {
      if (updates[i].collateralRisk != EngineFlags.KEEP_CURRENT) {
        _spokeReserveDebounces[ISpoke(updates[i].spoke)][IHub(updates[i].hub)][
          updates[i].underlying
        ].collateralRisk = currentTime;
      }
    }
    updates.executeSpokeReserveConfigUpdates();
  }

  function _executeDynamicReserveConfigs(
    IEngine.DynamicReserveConfigUpdate[] memory updates
  ) internal {
    uint40 currentTime = block.timestamp.toUint40();
    for (uint256 i; i < updates.length; ++i) {
      SpokeDynamicDebounce storage debounce = _spokeDynamicDebounces[ISpoke(updates[i].spoke)][
        IHub(updates[i].hub)
      ][updates[i].underlying];
      if (updates[i].collateralFactor != EngineFlags.KEEP_CURRENT) {
        debounce.collateralFactor = currentTime;
      }
      if (updates[i].maxLiquidationBonus != EngineFlags.KEEP_CURRENT) {
        debounce.maxLiquidationBonus = currentTime;
      }
    }
    updates.executeSpokeDynamicReserveConfigUpdates();
  }

  function _executeAddDynamicReserveConfigs(
    IEngine.DynamicReserveConfigAddition[] memory additions
  ) internal {
    uint40 currentTime = block.timestamp.toUint40();
    for (uint256 i; i < additions.length; ++i) {
      SpokeDynamicDebounce storage debounce = _spokeDynamicDebounces[ISpoke(additions[i].spoke)][
        IHub(additions[i].hub)
      ][additions[i].underlying];
      debounce.collateralFactor = currentTime;
      debounce.maxLiquidationBonus = currentTime;
    }
    additions.executeSpokeDynamicReserveConfigAdditions();
  }

  function _executeSpokeLiquidationConfigs(
    IEngine.LiquidationConfigUpdate[] memory updates
  ) internal {
    uint40 currentTime = block.timestamp.toUint40();
    for (uint256 i; i < updates.length; ++i) {
      SpokeLiquidationDebounce storage debounce = _spokeLiquidationDebounces[
        ISpoke(updates[i].spoke)
      ];
      if (updates[i].targetHealthFactor != EngineFlags.KEEP_CURRENT) {
        debounce.targetHealthFactor = currentTime;
      }
      if (updates[i].healthFactorForMaxBonus != EngineFlags.KEEP_CURRENT) {
        debounce.healthFactorForMaxBonus = currentTime;
      }
      if (updates[i].liquidationBonusFactor != EngineFlags.KEEP_CURRENT) {
        debounce.liquidationBonusFactor = currentTime;
      }
    }
    updates.executeSpokeLiquidationConfigUpdates();
  }

  function _executeLstPriceCaps(PriceCapLstUpdate[] calldata updates) internal {
    uint40 currentTime = block.timestamp.toUint40();
    for (uint256 i; i < updates.length; ++i) {
      address oracle = updates[i].oracle;
      _oracleDebounces[oracle] = currentTime;
      IPriceCapAdapter(oracle).setCapParameters(updates[i].priceCapUpdateParams);
      require(!IPriceCapAdapter(oracle).isCapped(), InvalidPriceCapUpdate());
    }
  }

  function _executeStablePriceCaps(PriceCapStableUpdate[] calldata updates) internal {
    uint40 currentTime = block.timestamp.toUint40();
    for (uint256 i; i < updates.length; ++i) {
      address oracle = updates[i].oracle;
      _oracleDebounces[oracle] = currentTime;
      IPriceCapAdapterStable(oracle).setPriceCap(updates[i].priceCap.toInt256());
    }
  }

  function _executePendleDiscountRates(DiscountRatePendleUpdate[] calldata updates) internal {
    uint40 currentTime = block.timestamp.toUint40();
    for (uint256 i; i < updates.length; ++i) {
      address oracle = updates[i].oracle;
      _oracleDebounces[oracle] = currentTime;
      IPendlePriceCapAdapter(oracle).setDiscountRatePerYear(updates[i].discountRate.toUint64());
    }
  }

  function _validateHubAssetIRs(IEngine.AssetConfigUpdate[] calldata updates) internal view {
    require(updates.length != 0, NoZeroUpdates());
    for (uint256 i; i < updates.length; ++i) {
      IHub hub = IHub(updates[i].hub);
      _requireHubNotRestricted(hub);
      require(updates[i].hubConfigurator == _config.hub.configurator, ConfiguratorMismatch());

      require(updates[i].liquidityFee == EngineFlags.KEEP_CURRENT, ParamChangeNotAllowed());
      require(updates[i].feeReceiver == EngineFlags.KEEP_CURRENT_ADDRESS, ParamChangeNotAllowed());
      require(updates[i].irStrategy == EngineFlags.KEEP_CURRENT_ADDRESS, ParamChangeNotAllowed());
      require(
        updates[i].reinvestmentController == EngineFlags.KEEP_CURRENT_ADDRESS,
        ParamChangeNotAllowed()
      );

      address asset = updates[i].underlying;
      IAssetInterestRateStrategy.InterestRateData memory current = _getCurrentIRData(hub, asset);
      HubRateConfig memory rateBounds = _config.hub.rate;
      HubAssetDebounce memory debounce = _hubAssetDebounces[hub][asset];

      _validateIRFieldUint16({
        currentValue: current.optimalUsageRatio,
        newValue: updates[i].irData.optimalUsageRatio,
        lastUpdated: debounce.optimalUsageRatio,
        riskConfig: rateBounds.optimalUsageRatio
      });
      _validateIRFieldUint32({
        currentValue: current.baseDrawnRate,
        newValue: updates[i].irData.baseDrawnRate,
        lastUpdated: debounce.baseDrawnRate,
        riskConfig: rateBounds.baseDrawnRate
      });
      _validateIRFieldUint32({
        currentValue: current.rateGrowthBeforeOptimal,
        newValue: updates[i].irData.rateGrowthBeforeOptimal,
        lastUpdated: debounce.rateGrowthBeforeOptimal,
        riskConfig: rateBounds.rateGrowthBeforeOptimal
      });
      _validateIRFieldUint32({
        currentValue: current.rateGrowthAfterOptimal,
        newValue: updates[i].irData.rateGrowthAfterOptimal,
        lastUpdated: debounce.rateGrowthAfterOptimal,
        riskConfig: rateBounds.rateGrowthAfterOptimal
      });
    }
  }

  function _validateHubSpokeCaps(IEngine.SpokeConfigUpdate[] calldata updates) internal view {
    require(updates.length != 0, NoZeroUpdates());
    for (uint256 i; i < updates.length; ++i) {
      IHub hub = IHub(updates[i].hub);
      ISpoke spoke = ISpoke(updates[i].spoke);
      address asset = updates[i].underlying;
      _requireHubNotRestricted(hub);
      require(updates[i].hubConfigurator == _config.hub.configurator, ConfiguratorMismatch());
      _requireSpokeNotRestricted(spoke);
      _requireSpokeHubNotRestricted(spoke, hub);
      _requireReserveNotRestricted(spoke, hub, asset);

      require(updates[i].riskPremiumThreshold == EngineFlags.KEEP_CURRENT, ParamChangeNotAllowed());
      require(updates[i].active == EngineFlags.KEEP_CURRENT, ParamChangeNotAllowed());
      require(updates[i].halted == EngineFlags.KEEP_CURRENT, ParamChangeNotAllowed());

      require(
        updates[i].addCap == EngineFlags.KEEP_CURRENT || updates[i].addCap != 0,
        InvalidUpdateToZero()
      );
      require(
        updates[i].drawCap == EngineFlags.KEEP_CURRENT || updates[i].drawCap != 0,
        InvalidUpdateToZero()
      );

      uint256 assetId = hub.getAssetId(asset);
      IHub.SpokeConfig memory current = hub.getSpokeConfig(assetId, address(spoke));
      HubCapConfig memory capBounds = _config.hub.cap;
      HubSpokeAssetDebounce memory debounce = _hubSpokeAssetDebounces[hub][spoke][asset];

      _validateParamUpdate(
        ParamUpdateValidationInput({
          currentValue: current.addCap,
          newValue: updates[i].addCap,
          lastUpdated: debounce.addCap,
          riskConfig: capBounds.addCap
        })
      );
      _validateParamUpdate(
        ParamUpdateValidationInput({
          currentValue: current.drawCap,
          newValue: updates[i].drawCap,
          lastUpdated: debounce.drawCap,
          riskConfig: capBounds.drawCap
        })
      );
    }
  }

  function _validateReserveConfigs(IEngine.ReserveConfigUpdate[] calldata updates) internal view {
    require(updates.length != 0, NoZeroUpdates());
    for (uint256 i; i < updates.length; ++i) {
      ISpoke spoke = ISpoke(updates[i].spoke);
      IHub hub = IHub(updates[i].hub);
      address asset = updates[i].underlying;
      _requireSpokeNotRestricted(spoke);
      require(updates[i].spokeConfigurator == _config.spoke.configurator, ConfiguratorMismatch());
      _requireHubNotRestricted(hub);
      _requireSpokeHubNotRestricted(spoke, hub);
      _requireReserveNotRestricted(spoke, hub, asset);

      require(updates[i].priceSource == EngineFlags.KEEP_CURRENT_ADDRESS, ParamChangeNotAllowed());
      require(updates[i].paused == EngineFlags.KEEP_CURRENT, ParamChangeNotAllowed());
      require(updates[i].frozen == EngineFlags.KEEP_CURRENT, ParamChangeNotAllowed());
      require(updates[i].borrowable == EngineFlags.KEEP_CURRENT, ParamChangeNotAllowed());
      require(updates[i].receiveSharesEnabled == EngineFlags.KEEP_CURRENT, ParamChangeNotAllowed());

      uint256 reserveId = _resolveReserveId(spoke, hub, asset);
      ISpoke.ReserveConfig memory current = spoke.getReserveConfig(reserveId);

      _validateParamUpdate(
        ParamUpdateValidationInput({
          currentValue: current.collateralRisk,
          newValue: updates[i].collateralRisk,
          lastUpdated: _spokeReserveDebounces[spoke][hub][asset].collateralRisk,
          riskConfig: _config.spoke.collateralRisk
        })
      );
    }
  }

  function _validateDynamicReserveConfigs(
    IEngine.DynamicReserveConfigUpdate[] calldata updates
  ) internal view {
    require(updates.length != 0, NoZeroUpdates());
    for (uint256 i; i < updates.length; ++i) {
      ISpoke spoke = ISpoke(updates[i].spoke);
      IHub hub = IHub(updates[i].hub);
      address asset = updates[i].underlying;
      _requireSpokeNotRestricted(spoke);
      require(updates[i].spokeConfigurator == _config.spoke.configurator, ConfiguratorMismatch());
      _requireHubNotRestricted(hub);
      _requireSpokeHubNotRestricted(spoke, hub);
      _requireReserveNotRestricted(spoke, hub, asset);

      require(updates[i].liquidationFee == EngineFlags.KEEP_CURRENT, ParamChangeNotAllowed());

      require(
        updates[i].collateralFactor == EngineFlags.KEEP_CURRENT || updates[i].collateralFactor != 0,
        InvalidUpdateToZero()
      );
      require(
        updates[i].maxLiquidationBonus == EngineFlags.KEEP_CURRENT ||
          updates[i].maxLiquidationBonus != 0,
        InvalidUpdateToZero()
      );

      uint32 key = updates[i].dynamicConfigKey.toUint32();
      uint256 reserveId = _resolveReserveId(spoke, hub, asset);
      ISpoke.DynamicReserveConfig memory current = spoke.getDynamicReserveConfig(reserveId, key);
      SpokeDynamicConfig memory dynamicBounds = _config.spoke.dynamicUpdate;
      SpokeDynamicDebounce memory debounce = _spokeDynamicDebounces[spoke][hub][asset];

      _validateParamUpdate(
        ParamUpdateValidationInput({
          currentValue: current.collateralFactor,
          newValue: updates[i].collateralFactor,
          lastUpdated: debounce.collateralFactor,
          riskConfig: dynamicBounds.collateralFactor
        })
      );
      _validateParamUpdate(
        ParamUpdateValidationInput({
          currentValue: current.maxLiquidationBonus,
          newValue: updates[i].maxLiquidationBonus,
          lastUpdated: debounce.maxLiquidationBonus,
          riskConfig: dynamicBounds.maxLiquidationBonus
        })
      );
    }
  }

  function _validateAddDynamicReserveConfigs(
    IEngine.DynamicReserveConfigAddition[] calldata additions
  ) internal view {
    require(additions.length != 0, NoZeroUpdates());
    for (uint256 i; i < additions.length; ++i) {
      ISpoke spoke = ISpoke(additions[i].spoke);
      IHub hub = IHub(additions[i].hub);
      address asset = additions[i].underlying;
      _requireSpokeNotRestricted(spoke);
      require(additions[i].spokeConfigurator == _config.spoke.configurator, ConfiguratorMismatch());
      _requireHubNotRestricted(hub);
      _requireSpokeHubNotRestricted(spoke, hub);
      _requireReserveNotRestricted(spoke, hub, asset);

      ISpoke.DynamicReserveConfig memory newCfg = additions[i].dynamicConfig;
      require(newCfg.collateralFactor != 0, InvalidUpdateToZero());
      require(newCfg.maxLiquidationBonus != 0, InvalidUpdateToZero());

      uint256 reserveId = _resolveReserveId(spoke, hub, asset);
      uint32 latestKey = spoke.getReserve(reserveId).dynamicConfigKey;
      ISpoke.DynamicReserveConfig memory ref = spoke.getDynamicReserveConfig(reserveId, latestKey);
      require(ref.collateralFactor != 0, NoExistingDynamicConfig());

      require(newCfg.liquidationFee == ref.liquidationFee, ParamChangeNotAllowed());

      SpokeDynamicConfig memory dynamicBounds = _config.spoke.dynamicAdd;
      SpokeDynamicDebounce memory debounce = _spokeDynamicDebounces[spoke][hub][asset];

      _validateParamUpdate(
        ParamUpdateValidationInput({
          currentValue: ref.collateralFactor,
          newValue: newCfg.collateralFactor,
          lastUpdated: debounce.collateralFactor,
          riskConfig: dynamicBounds.collateralFactor
        })
      );
      _validateParamUpdate(
        ParamUpdateValidationInput({
          currentValue: ref.maxLiquidationBonus,
          newValue: newCfg.maxLiquidationBonus,
          lastUpdated: debounce.maxLiquidationBonus,
          riskConfig: dynamicBounds.maxLiquidationBonus
        })
      );
    }
  }

  function _validateSpokeLiquidationConfigs(
    IEngine.LiquidationConfigUpdate[] calldata updates
  ) internal view {
    require(updates.length != 0, NoZeroUpdates());
    for (uint256 i; i < updates.length; ++i) {
      ISpoke spoke = ISpoke(updates[i].spoke);
      _requireSpokeNotRestricted(spoke);
      require(updates[i].spokeConfigurator == _config.spoke.configurator, ConfiguratorMismatch());

      require(
        updates[i].targetHealthFactor == EngineFlags.KEEP_CURRENT ||
          updates[i].targetHealthFactor != 0,
        InvalidUpdateToZero()
      );
      require(
        updates[i].healthFactorForMaxBonus == EngineFlags.KEEP_CURRENT ||
          updates[i].healthFactorForMaxBonus != 0,
        InvalidUpdateToZero()
      );
      require(
        updates[i].liquidationBonusFactor == EngineFlags.KEEP_CURRENT ||
          updates[i].liquidationBonusFactor != 0,
        InvalidUpdateToZero()
      );

      ISpoke.LiquidationConfig memory current = spoke.getLiquidationConfig();
      SpokeLiquidationConfig memory liquidationBounds = _config.spoke.liquidation;
      SpokeLiquidationDebounce memory debounce = _spokeLiquidationDebounces[spoke];

      _validateParamUpdate(
        ParamUpdateValidationInput({
          currentValue: current.targetHealthFactor,
          newValue: updates[i].targetHealthFactor,
          lastUpdated: debounce.targetHealthFactor,
          riskConfig: liquidationBounds.targetHealthFactor
        })
      );
      _validateParamUpdate(
        ParamUpdateValidationInput({
          currentValue: current.healthFactorForMaxBonus,
          newValue: updates[i].healthFactorForMaxBonus,
          lastUpdated: debounce.healthFactorForMaxBonus,
          riskConfig: liquidationBounds.healthFactorForMaxBonus
        })
      );
      _validateParamUpdate(
        ParamUpdateValidationInput({
          currentValue: current.liquidationBonusFactor,
          newValue: updates[i].liquidationBonusFactor,
          lastUpdated: debounce.liquidationBonusFactor,
          riskConfig: liquidationBounds.liquidationBonusFactor
        })
      );
    }
  }

  function _validateLstPriceCaps(PriceCapLstUpdate[] calldata updates) internal view {
    require(updates.length != 0, NoZeroUpdates());
    for (uint256 i; i < updates.length; ++i) {
      address oracle = updates[i].oracle;

      IPriceCapAdapter.PriceCapUpdateParams memory params = updates[i].priceCapUpdateParams;
      require(params.snapshotRatio != 0, InvalidUpdateToZero());
      require(params.snapshotTimestamp != 0, InvalidUpdateToZero());
      require(params.maxYearlyRatioGrowthPercent != 0, InvalidUpdateToZero());

      uint256 currentMaxYearlyGrowthPercent = IPriceCapAdapter(oracle)
        .getMaxYearlyGrowthRatePercent();
      uint104 currentRatio = IPriceCapAdapter(oracle).getRatio().toUint256().toUint104();

      // snapshot ratio must be backward-looking
      require(params.snapshotRatio <= currentRatio, UpdateNotInRange());

      _validateParamUpdate(
        ParamUpdateValidationInput({
          currentValue: currentMaxYearlyGrowthPercent,
          newValue: params.maxYearlyRatioGrowthPercent,
          lastUpdated: _oracleDebounces[oracle],
          riskConfig: _config.oracle.priceCapLst
        })
      );
    }
  }

  function _validateStablePriceCaps(PriceCapStableUpdate[] calldata updates) internal view {
    require(updates.length != 0, NoZeroUpdates());
    for (uint256 i; i < updates.length; ++i) {
      address oracle = updates[i].oracle;
      require(updates[i].priceCap != 0, InvalidUpdateToZero());

      uint256 currentPriceCap = IPriceCapAdapterStable(oracle).getPriceCap().toUint256();

      _validateParamUpdate(
        ParamUpdateValidationInput({
          currentValue: currentPriceCap,
          newValue: updates[i].priceCap,
          lastUpdated: _oracleDebounces[oracle],
          riskConfig: _config.oracle.priceCapStable
        })
      );
    }
  }

  function _validatePendleDiscountRates(DiscountRatePendleUpdate[] calldata updates) internal view {
    require(updates.length != 0, NoZeroUpdates());
    for (uint256 i; i < updates.length; ++i) {
      address oracle = updates[i].oracle;
      require(updates[i].discountRate != 0, InvalidUpdateToZero());

      uint256 currentDiscount = IPendlePriceCapAdapter(oracle).discountRatePerYear();

      _validateParamUpdate(
        ParamUpdateValidationInput({
          currentValue: currentDiscount,
          newValue: updates[i].discountRate,
          lastUpdated: _oracleDebounces[oracle],
          riskConfig: _config.oracle.discountRatePendle
        })
      );
    }
  }

  /// @dev Enforces the per-field `isChangeRelative` invariants for the `config`.
  function _validateConfig(Config calldata config) internal pure {
    require(!config.hub.rate.optimalUsageRatio.isChangeRelative, InvalidParamConfig());
    require(!config.hub.rate.baseDrawnRate.isChangeRelative, InvalidParamConfig());
    require(!config.hub.rate.rateGrowthBeforeOptimal.isChangeRelative, InvalidParamConfig());
    require(!config.hub.rate.rateGrowthAfterOptimal.isChangeRelative, InvalidParamConfig());
    require(config.hub.cap.addCap.isChangeRelative, InvalidParamConfig());
    require(config.hub.cap.drawCap.isChangeRelative, InvalidParamConfig());

    require(!config.spoke.collateralRisk.isChangeRelative, InvalidParamConfig());
    require(!config.spoke.dynamicUpdate.collateralFactor.isChangeRelative, InvalidParamConfig());
    require(!config.spoke.dynamicUpdate.maxLiquidationBonus.isChangeRelative, InvalidParamConfig());
    require(!config.spoke.dynamicAdd.collateralFactor.isChangeRelative, InvalidParamConfig());
    require(!config.spoke.dynamicAdd.maxLiquidationBonus.isChangeRelative, InvalidParamConfig());
    require(config.spoke.liquidation.targetHealthFactor.isChangeRelative, InvalidParamConfig());
    require(
      config.spoke.liquidation.healthFactorForMaxBonus.isChangeRelative,
      InvalidParamConfig()
    );
    require(
      !config.spoke.liquidation.liquidationBonusFactor.isChangeRelative,
      InvalidParamConfig()
    );

    require(config.oracle.priceCapLst.isChangeRelative, InvalidParamConfig());
    require(config.oracle.priceCapStable.isChangeRelative, InvalidParamConfig());
    require(!config.oracle.discountRatePendle.isChangeRelative, InvalidParamConfig());
  }

  function _requireHubNotRestricted(IHub hub) internal view {
    require(!_restrictedHubs[hub], HubIsRestricted());
  }

  function _requireSpokeNotRestricted(ISpoke spoke) internal view {
    require(!_restrictedSpokes[spoke], SpokeIsRestricted());
  }

  function _requireSpokeHubNotRestricted(ISpoke spoke, IHub hub) internal view {
    require(!_restrictedSpokeHubs[spoke][hub], SpokeHubIsRestricted());
  }

  function _requireReserveNotRestricted(ISpoke spoke, IHub hub, address asset) internal view {
    require(!_restrictedReserves[spoke][hub][asset], ReserveIsRestricted());
  }

  function _getCurrentIRData(
    IHub hub,
    address asset
  ) internal view returns (IAssetInterestRateStrategy.InterestRateData memory) {
    uint256 assetId = hub.getAssetId(asset);
    address irStrategy = hub.getAssetConfig(assetId).irStrategy;
    return IAssetInterestRateStrategy(irStrategy).getInterestRateData(assetId);
  }

  function _resolveReserveId(
    ISpoke spoke,
    IHub hub,
    address asset
  ) internal view returns (uint256) {
    uint256 assetId = hub.getAssetId(asset);
    return spoke.getReserveId(address(hub), assetId);
  }

  function _validateIRFieldUint16(
    uint256 currentValue,
    uint16 newValue,
    uint40 lastUpdated,
    RiskParamConfig memory riskConfig
  ) internal view {
    if (newValue == EngineFlags.KEEP_CURRENT_UINT16) return;
    _validateParamUpdate(
      ParamUpdateValidationInput({
        currentValue: currentValue,
        newValue: newValue,
        lastUpdated: lastUpdated,
        riskConfig: riskConfig
      })
    );
  }

  function _validateIRFieldUint32(
    uint256 currentValue,
    uint32 newValue,
    uint40 lastUpdated,
    RiskParamConfig memory riskConfig
  ) internal view {
    if (newValue == EngineFlags.KEEP_CURRENT_UINT32) return;
    _validateParamUpdate(
      ParamUpdateValidationInput({
        currentValue: currentValue,
        newValue: newValue,
        lastUpdated: lastUpdated,
        riskConfig: riskConfig
      })
    );
  }

  function _validateParamUpdate(ParamUpdateValidationInput memory input) internal view {
    if (input.newValue == EngineFlags.KEEP_CURRENT) return;
    require(
      // forge-lint: disable-next-line(block-timestamp)
      block.timestamp - input.lastUpdated >= input.riskConfig.minDelay,
      DebounceNotRespected()
    );
    require(
      _updateWithinAllowedRange({
        from: input.currentValue,
        to: input.newValue,
        maxPercentChange: input.riskConfig.maxPercentChange,
        isChangeRelative: input.riskConfig.isChangeRelative
      }),
      UpdateNotInRange()
    );
  }

  /// @dev When `isChangeRelative`, `maxPercentChange` is in BPS of `from`. Otherwise it is an
  /// absolute delta in the param's native units.
  /// NOTE: Does not allow changing when `from` is 0 and `isChangeRelative` is true.
  function _updateWithinAllowedRange(
    uint256 from,
    uint256 to,
    uint256 maxPercentChange,
    bool isChangeRelative
  ) internal pure returns (bool) {
    uint256 diff = from > to ? from - to : to - from;
    uint256 maxDiff = isChangeRelative ? from.percentMulDown(maxPercentChange) : maxPercentChange;
    return diff <= maxDiff;
  }
}
