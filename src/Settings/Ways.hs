module Settings.Ways (getLibraryWays, getRtsWays) where

import Base
import CmdLineFlag
import Oracles.Config.Flag
import Predicate
import Settings.Flavours.Quick
import Settings.Flavours.Quickest
import UserSettings

-- | Combine default library ways with user modifications.
getLibraryWays :: Expr [Way]
getLibraryWays = fromDiffExpr $ mconcat [ defaultLibraryWays
                                        , userLibraryWays
                                        , flavourLibraryWays ]

-- | Combine default RTS ways with user modifications.
getRtsWays :: Expr [Way]
getRtsWays = fromDiffExpr $ defaultRtsWays <> userRtsWays

-- TODO: what about profilingDynamic way? Do we need platformSupportsSharedLibs?
-- These are default ways for library packages:
-- * We always build 'vanilla' way.
-- * We build 'profiling' way when stage > Stage0.
-- * We build 'dynamic' way when stage > Stage0 and the platform supports it.
defaultLibraryWays :: Ways
defaultLibraryWays = mconcat
    [ append [vanilla]
    , notStage0 ? append [profiling]
    , notStage0 ? platformSupportsSharedLibs ? append [dynamic] ]

flavourLibraryWays :: Ways
flavourLibraryWays = case cmdFlavour of
    Default  -> mempty
    Quick    -> quickFlavourWays
    Quickest -> quickestFlavourWays

defaultRtsWays :: Ways
defaultRtsWays = do
    ways <- getLibraryWays
    mconcat
        [ append [ logging, debug, threaded, threadedDebug, threadedLogging ]
        , (profiling `elem` ways) ? append [threadedProfiling]
        , (dynamic `elem` ways) ?
          append [ dynamic, debugDynamic, threadedDynamic, threadedDebugDynamic
                 , loggingDynamic, threadedLoggingDynamic ] ]
