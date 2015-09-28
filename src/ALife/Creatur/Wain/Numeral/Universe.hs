------------------------------------------------------------------------
-- |
-- Module      :  ALife.Creatur.Wain.Numeral.Universe
-- Copyright   :  (c) Amy de Buitléir 2012-2015
-- License     :  BSD-style
-- Maintainer  :  amy@nualeargais.ie
-- Stability   :  experimental
-- Portability :  portable
--
-- Universe for image mining agents
--
------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
module ALife.Creatur.Wain.Numeral.Universe
  (
    -- * Constructors
    Universe(..),
    loadUniverse,
    U.Agent,
    -- * Lenses
    uExperimentName,
    uClock,
    uLogger,
    uDB,
    uNamer,
    uChecklist,
    uStatsFile,
    uRawStatsFile,
    uShowPredictorModels,
    uShowPredictions,
    uGenFmris,
    uSleepBetweenTasks,
    uImageDB,
    uImageWidth,
    uImageHeight,
    uClassifierSizeRange,
    uPredictorSizeRange,
    uDevotionRange,
    uMaturityRange,
    uMaxAge,
    uInitialPopulationSize,
    uEnergyBudget,
    uAllowedPopulationRange,
    uPopControl,
    uFrequencies,
    uBaseMetabolismDeltaE,
    uEnergyCostPerClassifierModel,
    uChildCostFactor,
    uCorrectDeltaE,
    uIncorrectDeltaE,
    uFlirtingDeltaE,
    uPopControlDeltaE,
    uClassifierThresholdRange,
    uClassifierR0Range,
    uClassifierDRange,
    uPredictorThresholdRange,
    uPredictorR0Range,
    uPredictorDRange,
    uDefaultOutcomeRange,
    uDepthRange,
    uBoredomDeltaRange,
    uPassionDeltaRange,
    uCheckpoints,
    -- * Other
    U.agentIds,
    U.currentTime,
    U.genName,
    U.getAgent,
    U.popSize,
    U.store,
    U.writeToLog
  ) where

import qualified ALife.Creatur as A
import qualified ALife.Creatur.Namer as N
import qualified ALife.Creatur.Checklist as CL
import qualified ALife.Creatur.Counter as K
import qualified ALife.Creatur.Database as D
import qualified ALife.Creatur.Database.CachedFileSystem as CFS
import qualified ALife.Creatur.Logger.SimpleLogger as SL
import ALife.Creatur.Persistent (Persistent, mkPersistent)
import qualified ALife.Creatur.Universe as U
import qualified ALife.Creatur.Wain.Checkpoint as CP
import ALife.Creatur.Wain.ImageDB (ImageDB, mkImageDB)
import ALife.Creatur.Wain.PlusMinusOne (PM1Double)
import ALife.Creatur.Wain.UnitInterval (UIDouble)
import Control.Exception (SomeException, try)
import Control.Lens hiding (Setting)
import Data.AppSettings (Setting(..), GetSetting(..),
  FileLocation(Path), readSettings)
import Data.Word (Word8, Word16)
import System.Directory (makeRelativeToCurrentDirectory)

data Universe a = Universe
  {
    _uExperimentName :: String,
    _uClock :: K.PersistentCounter,
    _uLogger :: SL.SimpleLogger,
    _uDB :: CFS.CachedFSDatabase a,
    _uNamer :: N.SimpleNamer,
    _uChecklist :: CL.PersistentChecklist,
    _uStatsFile :: FilePath,
    _uRawStatsFile :: FilePath,
    _uShowPredictorModels :: Bool,
    _uShowPredictions :: Bool,
    _uGenFmris :: Bool,
    _uSleepBetweenTasks :: Int,
    _uImageDB :: ImageDB,
    _uImageWidth :: Int,
    _uImageHeight :: Int,
    _uClassifierSizeRange :: (Word16, Word16),
    _uPredictorSizeRange :: (Word16, Word16),
    _uDevotionRange :: (UIDouble, UIDouble),
    _uMaturityRange :: (Word16, Word16),
    _uMaxAge :: Int,
    _uInitialPopulationSize :: Int,
    _uEnergyBudget :: Double,
    _uAllowedPopulationRange :: (Int, Int),
    _uPopControl :: Bool,
    _uFrequencies :: [Rational],
    _uBaseMetabolismDeltaE :: Double,
    _uEnergyCostPerClassifierModel :: Double,
    _uChildCostFactor :: Double,
    _uCorrectDeltaE :: Double,
    _uIncorrectDeltaE :: Double,
    _uFlirtingDeltaE :: Double,
    _uPopControlDeltaE :: Persistent Double,
    _uClassifierThresholdRange :: (UIDouble, UIDouble),
    _uClassifierR0Range :: (UIDouble, UIDouble),
    _uClassifierDRange :: (UIDouble, UIDouble),
    _uPredictorThresholdRange :: (UIDouble, UIDouble),
    _uPredictorR0Range :: (UIDouble, UIDouble),
    _uPredictorDRange :: (UIDouble, UIDouble),
    _uDefaultOutcomeRange :: (PM1Double, PM1Double),
    _uDepthRange :: (Word8, Word8),
    _uBoredomDeltaRange :: (UIDouble, UIDouble),
    _uPassionDeltaRange :: (UIDouble, UIDouble),
    _uCheckpoints :: [CP.Checkpoint]
  } deriving Show
makeLenses ''Universe

instance (A.Agent a, D.SizedRecord a) => U.Universe (Universe a) where
  type Agent (Universe a) = a
  type Clock (Universe a) = K.PersistentCounter
  clock = _uClock
  setClock u c = u { _uClock=c }
  type Logger (Universe a) = SL.SimpleLogger
  logger = _uLogger
  setLogger u l = u { _uLogger=l }
  type AgentDB (Universe a) = CFS.CachedFSDatabase a
  agentDB = _uDB
  setAgentDB u d = u { _uDB=d }
  type Namer (Universe a) = N.SimpleNamer
  agentNamer = _uNamer
  setNamer u n = u { _uNamer=n }
  type Checklist (Universe a) = CL.PersistentChecklist
  checklist = _uChecklist
  setChecklist u cl = u { _uChecklist=cl }

requiredSetting :: String -> Setting a
requiredSetting key
  = Setting key (error $ key ++ " not defined in configuration")

cExperimentName :: Setting String
cExperimentName = requiredSetting "experimentName"

cWorkingDir :: Setting FilePath
cWorkingDir = requiredSetting "workingDir"

cCacheSize :: Setting Int
cCacheSize = requiredSetting "cacheSize"

cShowPredictorModels :: Setting Bool
cShowPredictorModels = requiredSetting "showPredictorModels"

cShowPredictions :: Setting Bool
cShowPredictions = requiredSetting "showPredictions"

cGenFmris :: Setting Bool
cGenFmris = requiredSetting "genFMRIs"

cSleepBetweenTasks :: Setting Int
cSleepBetweenTasks = requiredSetting "sleepTimeBetweenTasks"

cImageDir :: Setting FilePath
cImageDir = requiredSetting "imageDir"

cImageWidth :: Setting Int
cImageWidth = requiredSetting "imageWidth"

cImageHeight :: Setting Int
cImageHeight = requiredSetting "imageHeight"

cClassifierSizeRange :: Setting (Word16, Word16)
cClassifierSizeRange
  = requiredSetting "classifierSizeRange"

cPredictorSizeRange :: Setting (Word16, Word16)
cPredictorSizeRange
  = requiredSetting "predictorSizeRange"

cDevotionRange :: Setting (UIDouble, UIDouble)
cDevotionRange = requiredSetting "devotionRange"

cMaturityRange :: Setting (Word16, Word16)
cMaturityRange = requiredSetting "maturityRange"

cMaxAge :: Setting Int
cMaxAge = requiredSetting "maxAge"

cInitialPopulationSize :: Setting Int
cInitialPopulationSize = requiredSetting "initialPopSize"

cAllowedPopulationRange :: Setting (Double, Double)
cAllowedPopulationRange = requiredSetting "allowedPopRange"

cPopControl :: Setting Bool
cPopControl = requiredSetting "popControl"

cFrequencies :: Setting [Rational]
cFrequencies = requiredSetting "frequencies"

cBaseMetabolismDeltaE :: Setting Double
cBaseMetabolismDeltaE = requiredSetting "baseMetabDeltaE"

cEnergyCostPerClassifierModel :: Setting Double
cEnergyCostPerClassifierModel
  = requiredSetting "energyCostPerClassifierModel"

cChildCostFactor :: Setting Double
cChildCostFactor = requiredSetting "childCostFactor"

cCorrectDeltaE :: Setting Double
cCorrectDeltaE = requiredSetting "correctDeltaE"

cIncorrectDeltaE :: Setting Double
cIncorrectDeltaE = requiredSetting "incorrectDeltaE"

cFlirtingDeltaE :: Setting Double
cFlirtingDeltaE = requiredSetting "flirtingDeltaE"

cClassifierThresholdRange :: Setting (UIDouble, UIDouble)
cClassifierThresholdRange = requiredSetting "classifierThresholdRange"

cClassifierR0Range :: Setting (UIDouble, UIDouble)
cClassifierR0Range = requiredSetting "classifierR0Range"

cClassifierDRange :: Setting (UIDouble, UIDouble)
cClassifierDRange = requiredSetting "classifierDecayRange"

cPredictorThresholdRange :: Setting (UIDouble, UIDouble)
cPredictorThresholdRange = requiredSetting "predictorThresholdRange"

cPredictorR0Range :: Setting (UIDouble, UIDouble)
cPredictorR0Range = requiredSetting "predictorR0Range"

cPredictorDRange :: Setting (UIDouble, UIDouble)
cPredictorDRange = requiredSetting "predictorDecayRange"

cDefaultOutcomeRange :: Setting (PM1Double, PM1Double)
cDefaultOutcomeRange = requiredSetting "defaultOutcomeRange"

cDepthRange :: Setting (Word8, Word8)
cDepthRange = requiredSetting "depthRange"

cBoredomDeltaRange :: Setting (UIDouble, UIDouble)
cBoredomDeltaRange = requiredSetting "boredomDeltaRange"

cPassionDeltaRange :: Setting (UIDouble, UIDouble)
cPassionDeltaRange = requiredSetting "passionDeltaRange"

cCheckpoints :: Setting [CP.Checkpoint]
cCheckpoints = requiredSetting "checkpoints"

loadUniverse :: IO (Universe a)
loadUniverse = do
  configFile <- Path <$> makeRelativeToCurrentDirectory "iomha.config"
  readResult <- try $ readSettings configFile
  case readResult of
    Right (_, GetSetting getSetting) ->
      return $ config2Universe getSetting
    Left (x :: SomeException) ->
      error $ "Error reading the config file: " ++ show x

config2Universe :: (forall a. Read a => Setting a -> a) -> Universe b
config2Universe getSetting =
  Universe
    {
      _uExperimentName = en,
      _uClock = K.mkPersistentCounter (workDir ++ "/clock"),
      _uLogger = SL.mkSimpleLogger (workDir ++ "/log/" ++ en ++ ".log"),
      _uDB = CFS.mkCachedFSDatabase (workDir ++ "/db")
               (getSetting cCacheSize),
      _uNamer = N.mkSimpleNamer (en ++ "_") (workDir ++ "/namer"),
      _uChecklist = CL.mkPersistentChecklist (workDir ++ "/todo"),
      _uStatsFile = workDir ++ "/statsFile",
      _uRawStatsFile = workDir ++ "/rawStatsFile",
      _uShowPredictorModels = getSetting cShowPredictorModels,
      _uShowPredictions = getSetting cShowPredictions,
      _uGenFmris = getSetting cGenFmris,
      _uSleepBetweenTasks = getSetting cSleepBetweenTasks,
      _uImageDB = mkImageDB imageDir,
      _uImageWidth = getSetting cImageWidth,
      _uImageHeight = getSetting cImageHeight,
      _uClassifierSizeRange = getSetting cClassifierSizeRange,
      _uPredictorSizeRange = getSetting cPredictorSizeRange,
      _uDevotionRange = getSetting cDevotionRange,
      _uMaturityRange = getSetting cMaturityRange,
      _uMaxAge = getSetting cMaxAge,
      _uInitialPopulationSize = p0,
      _uEnergyBudget = fromIntegral p0 * 0.5,
      _uAllowedPopulationRange = (a', b'),
      _uPopControl = getSetting cPopControl,
      _uFrequencies = getSetting cFrequencies,
      _uBaseMetabolismDeltaE = getSetting cBaseMetabolismDeltaE,
      _uEnergyCostPerClassifierModel
        = getSetting cEnergyCostPerClassifierModel,
      _uChildCostFactor = getSetting cChildCostFactor,
      _uFlirtingDeltaE = getSetting cFlirtingDeltaE,
      _uCorrectDeltaE = getSetting cCorrectDeltaE,
      _uIncorrectDeltaE = getSetting cIncorrectDeltaE,
      _uPopControlDeltaE
        = mkPersistent 0 (workDir ++ "/popControlDeltaE"),
      _uClassifierThresholdRange = getSetting cClassifierThresholdRange,
      _uClassifierR0Range = getSetting cClassifierR0Range,
      _uClassifierDRange = getSetting cClassifierDRange,
      _uPredictorThresholdRange = getSetting cPredictorThresholdRange,
      _uPredictorR0Range = getSetting cPredictorR0Range,
      _uPredictorDRange = getSetting cPredictorDRange,
      _uDefaultOutcomeRange = getSetting cDefaultOutcomeRange,
      _uDepthRange = getSetting cDepthRange,
      _uBoredomDeltaRange = getSetting cBoredomDeltaRange,
      _uPassionDeltaRange = getSetting cPassionDeltaRange,
      _uCheckpoints = getSetting cCheckpoints
    }
  where en = getSetting cExperimentName
        workDir = getSetting cWorkingDir
        imageDir = getSetting cImageDir
        p0 = getSetting cInitialPopulationSize
        (a, b) = getSetting cAllowedPopulationRange
        a' = round (fromIntegral p0 * a)
        b' = round (fromIntegral p0 * b)
