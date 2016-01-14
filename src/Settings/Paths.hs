module Settings.Paths (
    targetDirectory, targetPath, pkgHaddockFile, pkgLibraryFile,
    pkgGhciLibraryFile, packageConfiguration, packageConfigurationInitialised,
    includes, includesArgs
    ) where

import Base
import Expression
import Settings.User

-- User can override the default target directory settings given below
targetDirectory :: Stage -> Package -> FilePath
targetDirectory = userTargetDirectory

-- Path to the target directory from GHC source root
targetPath :: Stage -> Package -> FilePath
targetPath stage pkg = buildRootPath -/- targetDirectory stage pkg -/- pkgPath pkg

-- Relative path to a package haddock file, e.g.:
-- "libraries/array/dist-install/doc/html/array/array.haddock"
pkgHaddockFile :: Package -> FilePath
pkgHaddockFile pkg =
    targetPath Stage1 pkg -/- "doc/html" -/- name -/- name <.> "haddock"
  where name = pkgNameString pkg

-- Relative path to a package library file, e.g.:
-- "libraries/array/stage2/build/libHSarray-0.5.1.0.a"
-- TODO: remove code duplication for computing buildPath
pkgLibraryFile :: Stage -> Package -> String -> Way -> Action FilePath
pkgLibraryFile stage pkg componentId way = do
    extension <- libsuf way
    let buildPath = targetPath stage pkg -/- "build"
    return $ buildPath -/- "libHS" ++ componentId <.> extension

-- Relative path to a package ghci library file, e.g.:
-- "libraries/array/dist-install/build/HSarray-0.5.1.0.o"
pkgGhciLibraryFile :: Stage -> Package -> String -> FilePath
pkgGhciLibraryFile stage pkg componentId =
    targetPath stage pkg -/- "build" -/- "HS" ++ componentId <.> "o"

-- TODO: move to buildRootPath, see #113
packageConfiguration :: Stage -> FilePath
packageConfiguration Stage0 = buildRootPath -/- "stage0/bootstrapping.conf"
packageConfiguration _      = "inplace/lib/package.conf.d"

-- StageN, N > 0, share the same packageConfiguration (see above)
packageConfigurationInitialised :: Stage -> FilePath
packageConfigurationInitialised stage =
    shakeFilesPath -/- "package-configuration-initialised-"
    ++ stageString (min stage Stage1)

includes :: [FilePath]
includes = [ "includes", "includes/dist-derivedconstants/header" ]

includesArgs :: Args
includesArgs = append $ map ("-I" ++) includes
