#!/usr/bin/env python3
"""Generate a dependency-free Xcode project. Keep settings reviewable here."""
import hashlib
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
objects = {}


def identifier(label):
    return hashlib.sha256(label.encode()).hexdigest()[:24].upper()


def obj(label, isa, **fields):
    key = identifier(label)
    objects[key] = {"isa": isa, **fields}
    return key


def reference(path):
    return obj("file:" + path, "PBXFileReference", path=path, sourceTree="<group>", lastKnownFileType="sourcecode.swift")


core_paths = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "Sources/QuickConvertCore").glob("*.swift"))
app_paths = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "App").glob("*.swift"))
extension_paths = ["FinderExtension/FinderSync.swift"]
references = {p: reference(p) for p in core_paths + app_paths + extension_paths}
app_product = obj("app-product", "PBXFileReference", explicitFileType="wrapper.application", path="QuickConvert.app", sourceTree="BUILT_PRODUCTS_DIR")
ext_product = obj("ext-product", "PBXFileReference", explicitFileType="wrapper.app-extension", path="QuickConvertFinder.appex", sourceTree="BUILT_PRODUCTS_DIR")
products = obj("products", "PBXGroup", name="Products", children=[app_product, ext_product], sourceTree="<group>")
main_group = obj("main-group", "PBXGroup", children=list(references.values()) + [products], sourceTree="<group>")


def configs(label, common):
    entries = []
    for mode in ["Debug", "Release"]:
        settings = dict(common)
        settings.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O",
                         "DEBUG_INFORMATION_FORMAT": "dwarf" if mode == "Debug" else "dwarf-with-dsym"})
        if mode == "Debug":
            settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
        entries.append(obj(label + mode, "XCBuildConfiguration", name=mode, buildSettings=settings))
    return obj(label + "configs", "XCConfigurationList", buildConfigurations=entries, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")


project_configs = configs("project", {"MACOSX_DEPLOYMENT_TARGET": "13.0", "SDKROOT": "macosx",
    "SWIFT_VERSION": "5.0", "CLANG_ENABLE_MODULES": "YES", "ARCHS": "$(ARCHS_STANDARD)",
    "ONLY_ACTIVE_ARCH": "NO", "MARKETING_VERSION": "0.3.0", "CURRENT_PROJECT_VERSION": "3"})


def target_settings(name, info, entitlement, bundle):
    return {"PRODUCT_NAME": name, "PRODUCT_BUNDLE_IDENTIFIER": bundle,
            "INFOPLIST_FILE": info, "GENERATE_INFOPLIST_FILE": "NO",
            "CODE_SIGN_ENTITLEMENTS": entitlement, "CODE_SIGN_STYLE": "Automatic",
            "ENABLE_HARDENED_RUNTIME": "YES", "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/../Frameworks"]}


def source_phase(name, paths):
    files = [obj(name + p, "PBXBuildFile", fileRef=references[p]) for p in paths]
    return obj(name + "sources", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=files, runOnlyForDeploymentPostprocessing="0")


ext_settings = target_settings("QuickConvertFinder", "Configuration/Finder-Info.plist", "Configuration/Finder.entitlements", "com.quickconvert.app.finder")
ext_settings.update({"APPLICATION_EXTENSION_API_ONLY": "YES", "SKIP_INSTALL": "YES"})
shared = [p for p in core_paths if Path(p).name in ["Formats.swift", "Preferences.swift", "ConversionRequest.swift"]]
ext_target = obj("extension-target", "PBXNativeTarget", name="QuickConvertFinder", productName="QuickConvertFinder",
    productType="com.apple.product-type.app-extension", productReference=ext_product,
    buildConfigurationList=configs("extension", ext_settings), buildPhases=[source_phase("extension", extension_paths + shared)], buildRules=[], dependencies=[])
proxy = obj("proxy", "PBXContainerItemProxy", containerPortal=identifier("project"), proxyType="1", remoteGlobalIDString=ext_target, remoteInfo="QuickConvertFinder")
dependency = obj("extension-dependency", "PBXTargetDependency", target=ext_target, targetProxy=proxy)
embed_file = obj("embed-file", "PBXBuildFile", fileRef=ext_product, settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]})
embed = obj("embed-phase", "PBXCopyFilesBuildPhase", buildActionMask="2147483647", dstPath="", dstSubfolderSpec="13", files=[embed_file], name="Embed App Extensions", runOnlyForDeploymentPostprocessing="0")
app_target = obj("app-target", "PBXNativeTarget", name="QuickConvert", productName="QuickConvert",
    productType="com.apple.product-type.application", productReference=app_product,
    buildConfigurationList=configs("app", target_settings("QuickConvert", "Configuration/App-Info.plist", "Configuration/App.entitlements", "com.quickconvert.app")),
    buildPhases=[source_phase("app", app_paths + core_paths), embed], buildRules=[], dependencies=[dependency])
project = obj("project", "PBXProject", attributes={"LastUpgradeCheck": "1600", "BuildIndependentTargetsInParallel": "YES"},
    buildConfigurationList=project_configs, compatibilityVersion="Xcode 14.0", developmentRegion="zh_TW", hasScannedForEncodings="0",
    knownRegions=["zh_TW", "en", "Base"], mainGroup=main_group, productRefGroup=products, projectDirPath="", projectRoot="", targets=[app_target, ext_target])
destination = ROOT / "QuickConvert.xcodeproj"
destination.mkdir(exist_ok=True)
with (destination / "project.pbxproj").open("wb") as stream:
    plistlib.dump({"archiveVersion": "1", "classes": {}, "objectVersion": "56", "objects": objects, "rootObject": project}, stream, sort_keys=False)
schemes = destination / "xcshareddata/xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
(schemes / "QuickConvert.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="QuickConvert.app" BlueprintName="QuickConvert" ReferencedContainer="container:QuickConvert.xcodeproj"/>
</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
<BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="QuickConvert.app" BlueprintName="QuickConvert" ReferencedContainer="container:QuickConvert.xcodeproj"/></BuildableProductRunnable>
</LaunchAction>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(destination)
