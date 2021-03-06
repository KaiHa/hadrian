module Settings.Args (getArgs) where

import CmdLineFlag
import Expression
import Settings.Builders.Alex
import Settings.Builders.Ar
import Settings.Builders.DeriveConstants
import Settings.Builders.Cc
import Settings.Builders.Configure
import Settings.Builders.GenApply
import Settings.Builders.GenPrimopCode
import Settings.Builders.Ghc
import Settings.Builders.GhcCabal
import Settings.Builders.GhcPkg
import Settings.Builders.Haddock
import Settings.Builders.Happy
import Settings.Builders.Hsc2Hs
import Settings.Builders.HsCpp
import Settings.Builders.Ld
import Settings.Builders.Make
import Settings.Builders.Tar
import Settings.Flavours.Quick
import Settings.Flavours.Quickest
import Settings.Packages.Base
import Settings.Packages.Compiler
import Settings.Packages.Directory
import Settings.Packages.Ghc
import Settings.Packages.GhcCabal
import Settings.Packages.GhcPrim
import Settings.Packages.Haddock
import Settings.Packages.Hp2ps
import Settings.Packages.IntegerGmp
import Settings.Packages.IservBin
import Settings.Packages.Rts
import Settings.Packages.RunGhc
import Settings.Packages.Touchy
import Settings.Packages.Unlit
import UserSettings

getArgs :: Expr [String]
getArgs = fromDiffExpr $ mconcat [ defaultBuilderArgs
                                 , defaultPackageArgs
                                 , flavourArgs
                                 , userArgs ]

-- TODO: add src-hc-args = -H32m -O
-- TODO: GhcStage2HcOpts=-O2 unless GhcUnregisterised
-- TODO: compiler/stage1/build/Parser_HC_OPTS += -O0 -fno-ignore-interface-pragmas
-- TODO: compiler/main/GhcMake_HC_OPTS        += -auto-all
-- TODO: compiler/prelude/PrimOp_HC_OPTS  += -fforce-recomp
-- TODO: is GhcHcOpts=-Rghc-timing needed?
defaultBuilderArgs :: Args
defaultBuilderArgs = mconcat
    [ alexBuilderArgs
    , arBuilderArgs
    , ccBuilderArgs
    , configureBuilderArgs
    , deriveConstantsBuilderArgs
    , genApplyBuilderArgs
    , genPrimopCodeBuilderArgs
    , ghcBuilderArgs
    , ghcCabalBuilderArgs
    , ghcCabalHsColourBuilderArgs
    , ghcMBuilderArgs
    , ghcPkgBuilderArgs
    , haddockBuilderArgs
    , happyBuilderArgs
    , hsc2hsBuilderArgs
    , hsCppBuilderArgs
    , ldBuilderArgs
    , makeBuilderArgs
    , tarBuilderArgs ]

defaultPackageArgs :: Args
defaultPackageArgs = mconcat
    [ basePackageArgs
    , compilerPackageArgs
    , directoryPackageArgs
    , ghcPackageArgs
    , ghcCabalPackageArgs
    , ghcPrimPackageArgs
    , haddockPackageArgs
    , hp2psPackageArgs
    , integerGmpPackageArgs
    , iservBinPackageArgs
    , rtsPackageArgs
    , runGhcPackageArgs
    , touchyPackageArgs
    , unlitPackageArgs ]

flavourArgs :: Args
flavourArgs = case cmdFlavour of
    Default  -> mempty
    Quick    -> quickFlavourArgs
    Quickest -> quickestFlavourArgs
