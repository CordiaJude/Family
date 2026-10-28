#!/usr/bin/env python3
"""Generates Family.xcodeproj/project.pbxproj and the shared scheme.

The project uses file-system-synchronized groups (Xcode 16+), so source
files never need to be listed here: anything inside a target's folder is
compiled into that target. Run this only when targets, build settings or
package products change:

    python3 scripts/generate_project.py
"""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "Family.xcodeproj"


def oid(*parts: str) -> str:
    """Stable 24-hex-digit object ID derived from a name."""
    return hashlib.sha1("/".join(parts).encode()).hexdigest()[:24].upper()


def q(value: str) -> str:
    """Quotes a pbxproj string when needed."""
    safe = all(c.isalnum() or c in "._/$" for c in value) and value != ""
    safe = safe or (value.replace("_", "").isalnum() and value.isascii())
    return value if safe else '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(value, indent=1) -> str:
    pad = "\t" * indent
    if isinstance(value, dict):
        inner = "".join(f"{pad}\t{q(k)} = {render(v, indent + 1)};\n" for k, v in value.items())
        return "{\n" + inner + pad + "}"
    if isinstance(value, list):
        inner = "".join(f"{pad}\t{render(v, indent + 1)},\n" for v in value)
        return "(\n" + inner + pad + ")"
    return q(str(value))


# ---------------------------------------------------------------- targets

COMMON_TARGET_SETTINGS = {
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
    "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
}

TARGETS = [
    {
        "name": "Family",
        "folder": "App",
        "product": "Family.app",
        "type": "com.apple.product-type.application",
        "file_type": "wrapper.application",
        "packages": ["FamilyCore", "FamilyData", "FamilyDesign"],
        "embeds": ["FamilyWidgets", "FamilyShare"],
        "settings": {
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
            "ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS": "NO",
            "CODE_SIGN_ENTITLEMENTS": "Config/Family.entitlements",
            "ENABLE_PREVIEWS": "YES",
            "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_FILE": "Config/Family-Info.plist",
            "INFOPLIST_KEY_CFBundleDisplayName": "Family",
            "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.lifestyle",
            "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
            "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
            "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
            "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
            "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
            "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
            "PRODUCT_BUNDLE_IDENTIFIER": "$(FAMILY_BUNDLE_ID)",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "TARGETED_DEVICE_FAMILY": "1,2",
        },
    },
    {
        "name": "FamilyWidgets",
        "folder": "Widgets",
        "product": "FamilyWidgets.appex",
        "type": "com.apple.product-type.app-extension",
        "file_type": "wrapper.app-extension",
        "packages": ["FamilyCore", "FamilyData", "FamilyDesign"],
        "embeds": [],
        "settings": {
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
            "ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME": "WidgetBackground",
            # Timeline providers run off the main actor.
            "SWIFT_DEFAULT_ACTOR_ISOLATION": "nonisolated",
            "CODE_SIGN_ENTITLEMENTS": "Config/FamilyWidgets.entitlements",
            "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_FILE": "Config/FamilyWidgets-Info.plist",
            "INFOPLIST_KEY_CFBundleDisplayName": "Family",
            "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
            "PRODUCT_BUNDLE_IDENTIFIER": "$(FAMILY_BUNDLE_ID).widgets",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SKIP_INSTALL": "YES",
            "TARGETED_DEVICE_FAMILY": "1,2",
        },
    },
    {
        "name": "FamilyShare",
        "folder": "ShareExtension",
        "product": "FamilyShare.appex",
        "type": "com.apple.product-type.app-extension",
        "file_type": "wrapper.app-extension",
        "packages": ["FamilyCore", "FamilyData", "FamilyDesign"],
        "embeds": [],
        "settings": {
            "CODE_SIGN_ENTITLEMENTS": "Config/FamilyShare.entitlements",
            "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_FILE": "Config/FamilyShare-Info.plist",
            "INFOPLIST_KEY_CFBundleDisplayName": "Family",
            "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
            "PRODUCT_BUNDLE_IDENTIFIER": "$(FAMILY_BUNDLE_ID).share",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SKIP_INSTALL": "YES",
            "TARGETED_DEVICE_FAMILY": "1,2",
        },
    },
]

CONFIG_FILES = [
    ("Shared.xcconfig", "text.xcconfig"),
    ("Signing.xcconfig", "text.xcconfig"),
    ("Family.entitlements", "text.plist.entitlements"),
    ("FamilyWidgets.entitlements", "text.plist.entitlements"),
    ("FamilyShare.entitlements", "text.plist.entitlements"),
    ("Family-Info.plist", "text.plist.xml"),
    ("FamilyWidgets-Info.plist", "text.plist.xml"),
    ("FamilyShare-Info.plist", "text.plist.xml"),
]

PROJECT_SETTINGS = {
    "Debug": {
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": "DEBUG=1 $(inherited)",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(FAMILY_DEBUG_CONDITIONS) $(inherited)",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    },
    "Release": {
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_NS_ASSERTIONS": "NO",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "SYNC_ENABLED $(inherited)",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "VALIDATE_PRODUCT": "YES",
    },
}


def build() -> str:
    objects: dict[str, dict] = {}

    project_id = oid("project")
    main_group = oid("group", "main")
    products_group = oid("group", "products")
    config_group = oid("group", "config")
    package_ref = oid("package", "FamilyKit")

    config_refs = {}
    for name, ftype in CONFIG_FILES:
        ref = oid("file", name)
        config_refs[name] = ref
        objects[ref] = {"isa": "PBXFileReference", "lastKnownFileType": ftype, "path": name, "sourceTree": "<group>"}
    objects[config_group] = {
        "isa": "PBXGroup", "children": list(config_refs.values()), "path": "Config", "sourceTree": "<group>",
    }

    target_ids = {t["name"]: oid("target", t["name"]) for t in TARGETS}
    product_refs = {t["name"]: oid("product", t["name"]) for t in TARGETS}
    sync_groups = []

    for t in TARGETS:
        name = t["name"]
        sync = oid("sync", t["folder"])
        sync_groups.append(sync)
        objects[sync] = {"isa": "PBXFileSystemSynchronizedRootGroup", "path": t["folder"], "sourceTree": "<group>"}
        objects[product_refs[name]] = {
            "isa": "PBXFileReference", "explicitFileType": t["file_type"], "includeInIndex": "0",
            "path": t["product"], "sourceTree": "BUILT_PRODUCTS_DIR",
        }

        package_files = []
        package_deps = []
        for product in t["packages"]:
            dep = oid("pkgdep", name, product)
            bf = oid("buildfile", name, product)
            objects[dep] = {"isa": "XCSwiftPackageProductDependency", "package": package_ref, "productName": product}
            objects[bf] = {"isa": "PBXBuildFile", "productRef": dep}
            package_deps.append(dep)
            package_files.append(bf)

        sources = oid("phase", name, "sources")
        frameworks = oid("phase", name, "frameworks")
        resources = oid("phase", name, "resources")
        objects[sources] = {"isa": "PBXSourcesBuildPhase", "buildActionMask": "2147483647", "files": [], "runOnlyForDeploymentPostprocessing": "0"}
        objects[frameworks] = {"isa": "PBXFrameworksBuildPhase", "buildActionMask": "2147483647", "files": package_files, "runOnlyForDeploymentPostprocessing": "0"}
        objects[resources] = {"isa": "PBXResourcesBuildPhase", "buildActionMask": "2147483647", "files": [], "runOnlyForDeploymentPostprocessing": "0"}
        phases = [sources, frameworks, resources]

        dependencies = []
        if t["embeds"]:
            embed_files = []
            for embedded in t["embeds"]:
                bf = oid("embed", name, embedded)
                objects[bf] = {
                    "isa": "PBXBuildFile", "fileRef": product_refs[embedded],
                    "settings": {"ATTRIBUTES": ["RemoveHeadersOnCopy"]},
                }
                embed_files.append(bf)
                proxy = oid("proxy", name, embedded)
                objects[proxy] = {
                    "isa": "PBXContainerItemProxy", "containerPortal": project_id, "proxyType": "1",
                    "remoteGlobalIDString": target_ids[embedded], "remoteInfo": embedded,
                }
                dep = oid("targetdep", name, embedded)
                objects[dep] = {"isa": "PBXTargetDependency", "target": target_ids[embedded], "targetProxy": proxy}
                dependencies.append(dep)
            embed = oid("phase", name, "embed")
            objects[embed] = {
                "isa": "PBXCopyFilesBuildPhase", "buildActionMask": "2147483647", "dstPath": "",
                "dstSubfolderSpec": "13", "files": embed_files, "name": "Embed Foundation Extensions",
                "runOnlyForDeploymentPostprocessing": "0",
            }
            phases.append(embed)

        config_list = oid("configlist", name)
        config_ids = []
        for config in ("Debug", "Release"):
            cid = oid("config", name, config)
            config_ids.append(cid)
            objects[cid] = {
                "isa": "XCBuildConfiguration",
                "buildSettings": {**COMMON_TARGET_SETTINGS, **t["settings"]},
                "name": config,
            }
        objects[config_list] = {
            "isa": "XCConfigurationList", "buildConfigurations": config_ids,
            "defaultConfigurationIsVisible": "0", "defaultConfigurationName": "Release",
        }

        objects[target_ids[name]] = {
            "isa": "PBXNativeTarget",
            "buildConfigurationList": config_list,
            "buildPhases": phases,
            "buildRules": [],
            "dependencies": dependencies,
            "fileSystemSynchronizedGroups": [sync],
            "name": name,
            "packageProductDependencies": package_deps,
            "productName": name,
            "productReference": product_refs[name],
            "productType": t["type"],
        }

    objects[products_group] = {
        "isa": "PBXGroup", "children": list(product_refs.values()), "name": "Products", "sourceTree": "<group>",
    }
    objects[main_group] = {
        "isa": "PBXGroup", "children": sync_groups + [config_group, products_group], "sourceTree": "<group>",
    }
    objects[package_ref] = {"isa": "XCLocalSwiftPackageReference", "relativePath": "Packages/FamilyKit"}

    project_configs = []
    for config, settings in PROJECT_SETTINGS.items():
        cid = oid("config", "project", config)
        project_configs.append(cid)
        objects[cid] = {
            "isa": "XCBuildConfiguration",
            "baseConfigurationReference": config_refs["Shared.xcconfig"],
            "buildSettings": settings,
            "name": config,
        }
    project_config_list = oid("configlist", "project")
    objects[project_config_list] = {
        "isa": "XCConfigurationList", "buildConfigurations": project_configs,
        "defaultConfigurationIsVisible": "0", "defaultConfigurationName": "Release",
    }

    objects[project_id] = {
        "isa": "PBXProject",
        "attributes": {
            "BuildIndependentTargetsInParallel": "1",
            "LastSwiftUpdateCheck": "2600",
            "LastUpgradeCheck": "2600",
            "TargetAttributes": {target_ids[t["name"]]: {"CreatedOnToolsVersion": "26.0"} for t in TARGETS},
        },
        "buildConfigurationList": project_config_list,
        "developmentRegion": "en",
        "hasScannedForEncodings": "0",
        "knownRegions": ["en", "Base"],
        "mainGroup": main_group,
        "minimizedProjectReferenceProxies": "1",
        "packageReferences": [package_ref],
        "preferredProjectObjectVersion": "77",
        "productRefGroup": products_group,
        "projectDirPath": "",
        "projectRoot": "",
        "targets": [target_ids[t["name"]] for t in TARGETS],
    }

    # Group objects by isa, like Xcode does, for readable diffs.
    by_isa: dict[str, list[tuple[str, dict]]] = {}
    for key, obj in objects.items():
        by_isa.setdefault(obj["isa"], []).append((key, obj))
    body = ""
    for isa in sorted(by_isa):
        body += f"\n/* Begin {isa} section */\n"
        for key, obj in sorted(by_isa[isa]):
            body += f"\t\t{key} = {render(obj, 2)};\n"
        body += f"/* End {isa} section */\n"

    return (
        "// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 77;\n"
        f"\tobjects = {{\n{body}\t}};\n\trootObject = {project_id};\n}}\n"
    )


def scheme() -> str:
    app = TARGETS[0]
    tid = oid("target", app["name"])
    ref = f'''<BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{tid}"
               BuildableName = "{app["product"]}"
               BlueprintName = "{app["name"]}"
               ReferencedContainer = "container:Family.xcodeproj">
            </BuildableReference>'''
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            {ref}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {ref}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {ref}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''


if __name__ == "__main__":
    PROJECT.mkdir(exist_ok=True)
    (PROJECT / "project.pbxproj").write_text(build())
    schemes = PROJECT / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    (schemes / "Family.xcscheme").write_text(scheme())
    workspace = PROJECT / "project.xcworkspace"
    workspace.mkdir(exist_ok=True)
    (workspace / "contents.xcworkspacedata").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n<Workspace\n   version = "1.0">\n'
        '   <FileRef\n      location = "self:">\n   </FileRef>\n</Workspace>\n'
    )
    print("Wrote", PROJECT.relative_to(ROOT))
