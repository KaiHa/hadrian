module Rules.Compile (compilePackage) where

import Base
import Expression
import Oracles
import Rules.Actions
import Rules.Resources
import Settings

compilePackage :: Resources -> PartialTarget -> Rules ()
compilePackage _ target @ (PartialTarget stage pkg) = do
    let buildPath = targetPath stage pkg -/- "build"

    matchBuildResult buildPath "hi" ?> \hi ->
        if compileInterfaceFilesSeparately && not ("//HpcParser.*" ?== hi)
        then do
            let way = detectWay hi
            (src, deps) <- dependencies buildPath $ hi -<.> osuf way
            need $ src : deps
            build $ fullTargetWithWay target (Ghc stage) way [src] [hi]
        else need [ hi -<.> osuf (detectWay hi) ]

    matchBuildResult buildPath "hi-boot" ?> \hiboot ->
        if compileInterfaceFilesSeparately
        then do
            let way = detectWay hiboot
            (src, deps) <- dependencies buildPath $ hiboot -<.> obootsuf way
            need $ src : deps
            build $ fullTargetWithWay target (Ghc stage) way [src] [hiboot]
        else need [ hiboot -<.> obootsuf (detectWay hiboot) ]

    -- TODO: add dependencies for #include of .h and .hs-incl files (gcc -MM?)
    matchBuildResult buildPath "o" ?> \obj -> do
        (src, deps) <- dependencies buildPath obj
        if ("//*.c" ?== src)
        then do
            need $ src : deps
            build $ fullTarget target (Gcc stage) [src] [obj]
        else do
            let way = detectWay obj
            if compileInterfaceFilesSeparately && "//*.hs" ?== src && not ("//HpcParser.*" ?== src)
            then need $ (obj -<.> hisuf (detectWay obj)) : src : deps
            else need $ src : deps
            build $ fullTargetWithWay target (Ghc stage) way [src] [obj]

    -- TODO: get rid of these special cases
    matchBuildResult buildPath "o-boot" ?> \obj -> do
        (src, deps) <- dependencies buildPath obj
        let way = detectWay obj
        if compileInterfaceFilesSeparately
        then need $ (obj -<.> hibootsuf (detectWay obj)) : src : deps
        else need $ src : deps
        build $ fullTargetWithWay target (Ghc stage) way [src] [obj]
