module Rules.Sdist (buildSourceDist, sourceDistRules) where

import Base
import Builder
import Context
import Expression
import Oracles.Config.Setting
import Oracles.ModuleFiles
import Rules.Actions
import Rules.Generate
import Settings
import Settings.Packages.Rts

sourceDistRules :: Rules ()
sourceDistRules = do
    "sdist-ghc" ~> do
        version <- setting ProjectVersion
        need ["sdistprep/ghc-" ++ version ++ "-src.tar.xz"]
        putSuccess "| Done. "
    "sdistprep/ghc-*-src.tar.xz" %> \fname -> do
        stage0Packages <- interpretInContext (stageContext Stage0) getPackages
        stage1Packages <- interpretInContext (stageContext Stage1) getPackages
--        stage2Packages <- interpretInContext (stageContext Stage2) getPackages
        let tarName = takeFileName fname
        need $ ["sdist-ghc-" ++ pkgNameString x ++ "Stage0" | x <- stage0Packages]
            ++ ["sdist-ghc-" ++ pkgNameString x ++ "Stage1" | x <- stage1Packages]
            -- XXX: Is this necessary or is there an easier way? And which stages should
            --      we list here?
--            ++ ["sdist-ghc-" ++ pkgNameString x ++ "Stage2" | x <- stage2Packages]
            ++ [ "sdistprep/ghc" </> dropTarXz tarName </> "GIT_COMMIT_ID"
               , "sdistprep/ghc" </> dropTarXz tarName </> "VERSION" ]
        runBuilderWith [Cwd "sdistprep/ghc"] Tar ["cJf", ".." </> tarName, dropTarXz tarName]
    "sdistprep/ghc/ghc-*-src/GIT_COMMIT_ID" %> \fname ->
        setting ProjectGitCommitId >>= writeFileChanged fname
    "sdistprep/ghc/ghc-*-src/VERSION" %> \fname ->
        setting ProjectVersion >>= writeFileChanged fname
  where
    dropTarXz = dropExtension . dropExtension


buildSourceDist :: Context -> Rules ()
buildSourceDist context@(Context stage pkg _) = do
    "sdist-ghc-" ++ pkgNameString pkg ++ show stage  ~> do
        version <- setting ProjectVersion
        let dest = "sdistprep/ghc/ghc-" ++ version ++ "-src"
        copyContext dest context


copyContext :: FilePath -> Context -> Action ()
copyContext dest context =
    forM_ sdistFiles $ \ffunc -> do
        files <- ffunc context
        -- XXX: How to prevent copying generated files?
        forM_ files $ \src -> unless ("_build/" `isPrefixOf` src) $ do
            createDirectory $ dest </> takeDirectory src
            cpFile src
  where
    cpFile a = copyFile a (dest </> a)
    sdistFiles :: [Context -> Action [FilePath]]
    sdistFiles = [ haskellSources
                 , sequence . return . pkgLibraryFile
                 , const $ return [rtsConfIn]
                 , \(Context stage pkg _) -> return $ generatedDependencies stage pkg
                 , extraFiles ]
    -- XXX: What else do we need to copy?
    extraFiles _ = return
        [ "ANNOUNCE"
        , "HACKING.md"
        , "INSTALL.md"
        , "LICENSE"
        , "MAKEHELP.md"
        , "Makefile"
        , "README.md"
        , "aclocal.m4"
        , "boot"
        , "config.guess"
        , "config.sub"
        , "configure"
        , "configure.ac"
        , "ghc.mk"
        , "hadrian/LICENSE"
        , "hadrian/README.md"
        , "hadrian/appveyor.yml"
        , "hadrian/build.bat"
        , "hadrian/build.cabal.sh"
        , "hadrian/build.sh"
        , "hadrian/build.stack.sh"
        , "hadrian/cfg/config.h.in"
        , "hadrian/cfg/system.config.in"
        , "hadrian/doc/user-settings.md"
        , "hadrian/doc/windows.md"
        , "hadrian/hadrian.cabal"
        , "hadrian/src/Base.hs"
        , "hadrian/src/Builder.hs"
        , "hadrian/src/CmdLineFlag.hs"
        , "hadrian/src/Context.hs"
        , "hadrian/src/Environment.hs"
        , "hadrian/src/Expression.hs"
        , "hadrian/src/GHC.hs"
        , "hadrian/src/Main.hs"
        , "hadrian/src/Oracles/ArgsHash.hs"
        , "hadrian/src/Oracles/Config.hs"
        , "hadrian/src/Oracles/Config/Flag.hs"
        , "hadrian/src/Oracles/Config/Setting.hs"
        , "hadrian/src/Oracles/Dependencies.hs"
        , "hadrian/src/Oracles/DirectoryContent.hs"
        , "hadrian/src/Oracles/LookupInPath.hs"
        , "hadrian/src/Oracles/ModuleFiles.hs"
        , "hadrian/src/Oracles/PackageData.hs"
        , "hadrian/src/Oracles/PackageDatabase.hs"
        , "hadrian/src/Oracles/WindowsPath.hs"
        , "hadrian/src/Package.hs"
        , "hadrian/src/Predicate.hs"
        , "hadrian/src/Rules.hs"
        , "hadrian/src/Rules/Actions.hs"
        , "hadrian/src/Rules/Cabal.hs"
        , "hadrian/src/Rules/Clean.hs"
        , "hadrian/src/Rules/Compile.hs"
        , "hadrian/src/Rules/Configure.hs"
        , "hadrian/src/Rules/Data.hs"
        , "hadrian/src/Rules/Dependencies.hs"
        , "hadrian/src/Rules/Documentation.hs"
        , "hadrian/src/Rules/Generate.hs"
        , "hadrian/src/Rules/Generators/Common.hs"
        , "hadrian/src/Rules/Generators/ConfigHs.hs"
        , "hadrian/src/Rules/Generators/GhcAutoconfH.hs"
        , "hadrian/src/Rules/Generators/GhcBootPlatformH.hs"
        , "hadrian/src/Rules/Generators/GhcPlatformH.hs"
        , "hadrian/src/Rules/Generators/GhcSplit.hs"
        , "hadrian/src/Rules/Generators/GhcVersionH.hs"
        , "hadrian/src/Rules/Generators/VersionHs.hs"
        , "hadrian/src/Rules/Gmp.hs"
        , "hadrian/src/Rules/Libffi.hs"
        , "hadrian/src/Rules/Library.hs"
        , "hadrian/src/Rules/Oracles.hs"
        , "hadrian/src/Rules/Perl.hs"
        , "hadrian/src/Rules/Program.hs"
        , "hadrian/src/Rules/Register.hs"
        , "hadrian/src/Rules/Sdist.hs"
        , "hadrian/src/Rules/Selftest.hs"
        , "hadrian/src/Rules/Test.hs"
        , "hadrian/src/Rules/Wrappers/Ghc.hs"
        , "hadrian/src/Rules/Wrappers/GhcPkg.hs"
        , "hadrian/src/Settings.hs"
        , "hadrian/src/Settings/Args.hs"
        , "hadrian/src/Settings/Builders/Alex.hs"
        , "hadrian/src/Settings/Builders/Ar.hs"
        , "hadrian/src/Settings/Builders/Cc.hs"
        , "hadrian/src/Settings/Builders/Common.hs"
        , "hadrian/src/Settings/Builders/Configure.hs"
        , "hadrian/src/Settings/Builders/DeriveConstants.hs"
        , "hadrian/src/Settings/Builders/GenApply.hs"
        , "hadrian/src/Settings/Builders/GenPrimopCode.hs"
        , "hadrian/src/Settings/Builders/Ghc.hs"
        , "hadrian/src/Settings/Builders/GhcCabal.hs"
        , "hadrian/src/Settings/Builders/GhcPkg.hs"
        , "hadrian/src/Settings/Builders/Haddock.hs"
        , "hadrian/src/Settings/Builders/Happy.hs"
        , "hadrian/src/Settings/Builders/HsCpp.hs"
        , "hadrian/src/Settings/Builders/Hsc2Hs.hs"
        , "hadrian/src/Settings/Builders/Ld.hs"
        , "hadrian/src/Settings/Builders/Make.hs"
        , "hadrian/src/Settings/Builders/Tar.hs"
        , "hadrian/src/Settings/Default.hs"
        , "hadrian/src/Settings/Flavours/Quick.hs"
        , "hadrian/src/Settings/Packages.hs"
        , "hadrian/src/Settings/Packages/Base.hs"
        , "hadrian/src/Settings/Packages/Compiler.hs"
        , "hadrian/src/Settings/Packages/Directory.hs"
        , "hadrian/src/Settings/Packages/Ghc.hs"
        , "hadrian/src/Settings/Packages/GhcCabal.hs"
        , "hadrian/src/Settings/Packages/GhcPrim.hs"
        , "hadrian/src/Settings/Packages/Haddock.hs"
        , "hadrian/src/Settings/Packages/Hp2ps.hs"
        , "hadrian/src/Settings/Packages/IntegerGmp.hs"
        , "hadrian/src/Settings/Packages/IservBin.hs"
        , "hadrian/src/Settings/Packages/Rts.hs"
        , "hadrian/src/Settings/Packages/RunGhc.hs"
        , "hadrian/src/Settings/Packages/Touchy.hs"
        , "hadrian/src/Settings/Packages/Unlit.hs"
        , "hadrian/src/Settings/Paths.hs"
        , "hadrian/src/Settings/Ways.hs"
        , "hadrian/src/Stage.hs"
        , "hadrian/src/Target.hs"
        , "hadrian/src/UserSettings.hs"
        , "hadrian/src/Way.hs"
        , "hadrian/stack.yaml"
        , "install-sh"
        , "packages"
        , "settings.in" ]
