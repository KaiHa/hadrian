module Settings.Packages.Rts (
    rtsPackageArgs, rtsConfIn, rtsConf, rtsLibffiLibraryName
    ) where

import Base
import GHC
import Oracles.Config.Flag
import Oracles.Config.Setting
import Predicate
import Settings
import Settings.Builders.Common

rtsConfIn :: FilePath
rtsConfIn = pkgPath rts -/- "package.conf.in"

-- TODO: move to buildRootPath, see #113
rtsConf :: FilePath
rtsConf = pkgPath rts -/- contextDirectory rtsContext -/- "package.conf.inplace"

rtsLibffiLibraryName :: Action FilePath
rtsLibffiLibraryName = do
    useSystemFfi <- flag UseSystemFfi
    windows      <- windowsHost
    case (useSystemFfi, windows) of
      (True , False) -> return "ffi"
      (False, False) -> return "Cffi"
      (_    , True ) -> return "Cffi-6"

rtsPackageArgs :: Args
rtsPackageArgs = package rts ? do
    let yesNo = lift . fmap (\x -> if x then "YES" else "NO")
    projectVersion <- getSetting ProjectVersion
    hostPlatform   <- getSetting HostPlatform
    hostArch       <- getSetting HostArch
    hostOs         <- getSetting HostOs
    hostVendor     <- getSetting HostVendor
    buildPlatform  <- getSetting BuildPlatform
    buildArch      <- getSetting BuildArch
    buildOs        <- getSetting BuildOs
    buildVendor    <- getSetting BuildVendor
    targetPlatform <- getSetting TargetPlatform
    targetArch     <- getSetting TargetArch
    targetOs       <- getSetting TargetOs
    targetVendor   <- getSetting TargetVendor
    ghcUnreg       <- yesNo $ flag GhcUnregisterised
    ghcEnableTNC   <- yesNo ghcEnableTablesNextToCode
    way            <- getWay
    path           <- getBuildPath
    top            <- getTopDirectory
    libffiName     <- lift $ rtsLibffiLibraryName
    ffiIncludeDir  <- getSetting FfiIncludeDir
    ffiLibraryDir  <- getSetting FfiLibDir
    mconcat
        [ builder Cc ? mconcat
          [ arg "-Irts"
          , arg $ "-I" ++ path
          , arg $ "-DRtsWay=\"rts_" ++ show way ++ "\""
          -- rts *must* be compiled with optimisations. The INLINE_HEADER macro
          -- requires that functions are inlined to work as expected. Inlining
          -- only happens for optimised builds. Otherwise we can assume that
          -- there is a non-inlined variant to use instead. But rts does not
          -- provide non-inlined alternatives and hence needs the function to
          -- be inlined. See also #90.
          , arg "-O2"

          , way == threaded ? arg "-DTHREADED_RTS"

          , (input "//RtsMessages.c" ||^ input "//Trace.c") ?
            arg ("-DProjectVersion=" ++ show projectVersion)

          , input "//RtsUtils.c" ? append
            [ "-DProjectVersion="            ++ show projectVersion
            , "-DHostPlatform="              ++ show hostPlatform
            , "-DHostArch="                  ++ show hostArch
            , "-DHostOS="                    ++ show hostOs
            , "-DHostVendor="                ++ show hostVendor
            , "-DBuildPlatform="             ++ show buildPlatform
            , "-DBuildArch="                 ++ show buildArch
            , "-DBuildOS="                   ++ show buildOs
            , "-DBuildVendor="               ++ show buildVendor
            , "-DTargetPlatform="            ++ show targetPlatform
            , "-DTargetArch="                ++ show targetArch
            , "-DTargetOS="                  ++ show targetOs
            , "-DTargetVendor="              ++ show targetVendor
            , "-DGhcUnregisterised="         ++ show ghcUnreg
            , "-DGhcEnableTablesNextToCode=" ++ show ghcEnableTNC ]

            , input "//Evac.c"     ? arg "-funroll-loops"
            , input "//Evac_thr.c" ? arg "-funroll-loops"

            , input "//Evac_thr.c" ? append [ "-DPARALLEL_GC", "-Irts/sm" ]
            , input "//Scav_thr.c" ? append [ "-DPARALLEL_GC", "-Irts/sm" ]
            ]

        , builder Ghc ? (arg "-Irts" <> includesArgs)

        , builder (GhcPkg Stage1) ? mconcat
          [ remove ["rts/stage1/inplace-pkg-config"] -- TODO: fix, see #113
          , arg rtsConf ]

        , builder HsCpp ? append
          [ "-DTOP="             ++ show top
          , "-DFFI_INCLUDE_DIR=" ++ show ffiIncludeDir
          , "-DFFI_LIB_DIR="     ++ show ffiLibraryDir
          , "-DFFI_LIB="         ++ show libffiName ]
        ]


-- # If we're compiling on windows, enforce that we only support XP+
-- # Adding this here means it doesn't have to be done in individual .c files
-- # and also centralizes the versioning.
-- ifeq "$$(TargetOS_CPP)" "mingw32"
-- rts_dist_$1_CC_OPTS += -DWINVER=$(rts_WINVER)
-- endif

-- #-----------------------------------------------------------------------------
-- # Use system provided libffi

-- ifeq "$(UseSystemLibFFI)" "YES"

-- rts_PACKAGE_CPP_OPTS += -DFFI_INCLUDE_DIR=$(FFIIncludeDir)
-- rts_PACKAGE_CPP_OPTS += -DFFI_LIB_DIR=$(FFILibDir)
-- rts_PACKAGE_CPP_OPTS += '-DFFI_LIB='

-- endif

-- #-----------------------------------------------------------------------------
-- # Add support for reading DWARF debugging information, if available

-- ifeq "$(GhcRtsWithLibdw)" "YES"
-- rts_CC_OPTS          += -DUSE_LIBDW
-- rts_PACKAGE_CPP_OPTS += -DUSE_LIBDW
-- endif

-- # If -DDEBUG is in effect, adjust package conf accordingly..
-- ifneq "$(strip $(filter -optc-DDEBUG,$(GhcRtsHcOpts)))" ""
-- rts_PACKAGE_CPP_OPTS += -DDEBUG
-- endif

-- ifeq "$(HaveLibMingwEx)" "YES"
-- rts_PACKAGE_CPP_OPTS += -DHAVE_LIBMINGWEX
-- endif



-- #-----------------------------------------------------------------------------
-- # Flags for compiling specific files
-- #
-- #

-- # Compile various performance-critical pieces *without* -fPIC -dynamic
-- # even when building a shared library.  If we don't do this, then the
-- # GC runs about 50% slower on x86 due to the overheads of PIC.  The
-- # cost of doing this is a little runtime linking and less sharing, but
-- # not much.
-- #
-- # On x86_64 this doesn't work, because all objects in a shared library
-- # must be compiled with -fPIC (since the 32-bit relocations generated
-- # by the default small memory can't be resolved at runtime).  So we
-- # only do this on i386.
-- #
-- # This apparently doesn't work on OS X (Darwin) nor on Solaris.
-- # On Darwin we get errors of the form
-- #
-- #  ld: absolute addressing (perhaps -mdynamic-no-pic) used in _stg_ap_0_fast from rts/dist/build/Apply.dyn_o not allowed in slidable image
-- #
-- # and lots of these warnings:
-- #
-- #  ld: warning codegen in _stg_ap_pppv_fast (offset 0x0000005E) prevents image from loading in dyld shared cache
-- #
-- # On Solaris we get errors like:
-- #
-- # Text relocation remains                         referenced
-- #     against symbol                  offset      in file
-- # .rodata (section)                   0x11        rts/dist/build/Apply.dyn_o
-- #   ...
-- # ld: fatal: relocations remain against allocatable but non-writable sections
-- # collect2: ld returned 1 exit status

-- ifeq "$(TargetArch_CPP)" "i386"
-- i386_SPEED_HACK := "YES"
-- ifeq "$(TargetOS_CPP)" "darwin"
-- i386_SPEED_HACK := "NO"
-- endif
-- ifeq "$(TargetOS_CPP)" "solaris2"
-- i386_SPEED_HACK := "NO"
-- endif
-- endif

-- ifeq "$(TargetArch_CPP)" "i386"
-- ifeq "$(i386_SPEED_HACK)" "YES"
-- rts/sm/Evac_HC_OPTS           += -fno-PIC
-- rts/sm/Evac_thr_HC_OPTS       += -fno-PIC
-- rts/sm/Scav_HC_OPTS           += -fno-PIC
-- rts/sm/Scav_thr_HC_OPTS       += -fno-PIC
-- rts/sm/Compact_HC_OPTS        += -fno-PIC
-- rts/sm/GC_HC_OPTS             += -fno-PIC

-- # -static is also necessary for these bits, otherwise the NCG
-- # -generates dynamic references:
-- rts/Updates_HC_OPTS += -fno-PIC -static
-- rts/StgMiscClosures_HC_OPTS += -fno-PIC -static
-- rts/PrimOps_HC_OPTS += -fno-PIC -static
-- rts/Apply_HC_OPTS += -fno-PIC -static
-- rts/dist/build/AutoApply_HC_OPTS += -fno-PIC -static
-- endif
-- endif

-- # add CFLAGS for libffi
-- # ffi.h triggers prototype warnings, so disable them here:
-- ifeq "$(UseSystemLibFFI)" "YES"
-- LIBFFI_CFLAGS = $(addprefix -I,$(FFIIncludeDir))
-- else
-- LIBFFI_CFLAGS =
-- endif
-- rts/Interpreter_CC_OPTS += -Wno-strict-prototypes $(LIBFFI_CFLAGS)
-- rts/Adjustor_CC_OPTS    += -Wno-strict-prototypes $(LIBFFI_CFLAGS)
-- rts/sm/Storage_CC_OPTS  += -Wno-strict-prototypes $(LIBFFI_CFLAGS)

-- # inlining warnings happen in Compact
-- rts/sm/Compact_CC_OPTS += -Wno-inline

-- # emits warnings about call-clobbered registers on x86_64
-- rts/StgCRun_CC_OPTS += -w

-- rts/RetainerProfile_CC_OPTS += -w
-- rts/RetainerSet_CC_OPTS += -Wno-format
-- # On Windows:
-- rts/win32/ConsoleHandler_CC_OPTS += -w
-- rts/win32/ThrIOManager_CC_OPTS += -w
-- # The above warning suppression flags are a temporary kludge.
-- # While working on this module you are encouraged to remove it and fix
-- # any warnings in the module. See
-- #     http://ghc.haskell.org/trac/ghc/wiki/WorkingConventions#Warnings
-- # for details

-- # Without this, thread_obj will not be inlined (at least on x86 with GCC 4.1.0)
-- ifneq "$(CC_CLANG_BACKEND)" "1"
-- rts/sm/Compact_CC_OPTS += -finline-limit=2500
-- endif
