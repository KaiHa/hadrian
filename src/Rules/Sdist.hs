module Rules.Sdist (sourceDistRules) where

import Base
import Builder
import Oracles.Config.Setting
import Rules.Actions
import Settings

sourceDistRules :: Rules ()
sourceDistRules = do
    "sdist-ghc" ~> do
        version <- setting ProjectVersion
        let dest = "sdistprep/ghc/ghc-" ++ version
            tarName = "../ghc-" ++ version ++ "-src.tar.xz"
            cpFile a = copyFile      ("hadrian" -/- a) (dest -/- "hadrian" -/- a)
            cpDir  a = copyDirectory ("hadrian" -/- a) (dest -/- "hadrian")
        runBuilder (Make ".") [ "--no-print-directory", "-f", "ghc.mk"
                              , "sdist-ghc-prep", "NO_INCLUDE_DEPS=YES"
                              , "NO_INCLUDE_PKGDATA=YES"]
        createDirectory $ dest -/- "hadrian"
        cpDir  "cfg"
        cpDir  "doc"
        cpDir  "src"
        cpDir  "src"
        cpFile "LICENSE"
        cpFile "Makefile"
        cpFile "README.md"
        cpFile "appveyor.yml"
        cpFile "build.bat"
        cpFile "build.cabal.sh"
        cpFile "build.sh"
        cpFile "build.stack.sh"
        cpFile "hadrian.cabal"
        cpFile "stack.yaml"
        runBuilderWith [Cwd "sdistprep/ghc"] Tar ["cJf", tarName, "ghc-" ++ version]
        putSuccess "| Done. "
