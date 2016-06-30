module Rules (topLevelTargets, buildRules) where

import Data.Foldable

import Base
import Context
import Expression
import GHC
import qualified Rules.Compile
import qualified Rules.Data
import qualified Rules.Dependencies
import qualified Rules.Documentation
import qualified Rules.Generate
import qualified Rules.Cabal
import qualified Rules.Configure
import qualified Rules.Gmp
import qualified Rules.Libffi
import qualified Rules.Library
import qualified Rules.Perl
import qualified Rules.Program
import qualified Rules.Register
import qualified Rules.Sdist
import Settings

allStages :: [Stage]
allStages = [minBound ..]

-- | 'need' all top-level build targets
topLevelTargets :: Rules ()
topLevelTargets = do

    want $ Rules.Generate.installTargets

    -- TODO: do we want libffiLibrary to be a top-level target?

    action $ do -- TODO: Add support for all rtsWays
        rtsLib    <- pkgLibraryFile $ rtsContext { way = vanilla  }
        rtsThrLib <- pkgLibraryFile $ rtsContext { way = threaded }
        need [ rtsLib, rtsThrLib ]

    for_ allStages $ \stage ->
        for_ (knownPackages \\ [rts, libffi]) $ \pkg -> action $ do
            let context = vanillaContext stage pkg
            activePackages <- interpretInContext context getPackages
            when (pkg `elem` activePackages) $
                if isLibrary pkg
                then do -- build a library
                    ways <- interpretInContext context getLibraryWays
                    libs <- mapM (pkgLibraryFile . Context stage pkg) ways
                    docs <- interpretInContext context buildHaddock
                    need $ libs ++ [ pkgHaddockFile context | docs && stage == Stage1 ]
                else do -- otherwise build a program
                    need [ fromJust $ programPath context ] -- TODO: drop fromJust

packageRules :: Rules ()
packageRules = do
    -- We cannot register multiple GHC packages in parallel. Also we cannot run
    -- GHC when the package database is being mutated by "ghc-pkg". This is a
    -- classic concurrent read exclusive write (CREW) conflict.
    let maxConcurrentReaders = 1000
    packageDb <- newResource "package-db" maxConcurrentReaders
    let readPackageDb  = [(packageDb, 1)]
        writePackageDb = [(packageDb, maxConcurrentReaders)]

    -- TODO: not all build rules make sense for all stage/package combinations
    let contexts        = liftM3 Context        allStages knownPackages allWays
        vanillaContexts = liftM2 vanillaContext allStages knownPackages

    for_ contexts $ mconcat
        [ Rules.Compile.compilePackage readPackageDb
        , Rules.Library.buildPackageLibrary ]

    for_ vanillaContexts $ mconcat
        [ Rules.Data.buildPackageData
        , Rules.Dependencies.buildPackageDependencies readPackageDb
        , Rules.Documentation.buildPackageDocumentation
        , Rules.Library.buildPackageGhciLibrary
        , Rules.Generate.generatePackageCode
        , Rules.Program.buildProgram readPackageDb
        , Rules.Register.registerPackage writePackageDb
        , Rules.Sdist.buildSourceDist ]

buildRules :: Rules ()
buildRules = do
    Rules.Cabal.cabalRules
    Rules.Configure.configureRules
    Rules.Generate.copyRules
    Rules.Generate.generateRules
    Rules.Gmp.gmpRules
    Rules.Libffi.libffiRules
    packageRules
    Rules.Perl.perlScriptRules
