"""Generate the dependency-free Xcode project on Windows or macOS."""
import hashlib
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "ios/LocalDemo.xcodeproj"
objects = {}


def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def obj(key_name, isa, **fields):
    key = uid(key_name)
    objects[key] = {"isa": isa, **fields}
    return key


def encode(value, level=0):
    if isinstance(value, dict):
        return "{\n" + "".join("\t" * (level + 1) + encode(k) + " = " + encode(v, level + 1) + ";\n" for k, v in value.items()) + "\t" * level + "}"
    if isinstance(value, list):
        return "(" + ", ".join(encode(v, level) for v in value) + ")"
    value = str(value)
    if re.fullmatch(r"[A-Za-z0-9_./]+", value):
        return value
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def configs(name, base):
    configurations = []
    for mode in ("Debug", "Release"):
        settings = dict(base)
        settings.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O", "DEBUG_INFORMATION_FORMAT": "dwarf" if mode == "Debug" else "dwarf-with-dsym"})
        if mode == "Debug":
            settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
        configurations.append(obj(name + mode, "XCBuildConfiguration", name=mode, buildSettings=settings))
    return obj(name + "Configurations", "XCConfigurationList", buildConfigurations=configurations, defaultConfigurationIsVisible=0, defaultConfigurationName="Release")


def source_group(folder):
    references, builds = [], []
    for path in sorted((ROOT / "ios" / folder).glob("*.swift")):
        ref = obj(str(path.relative_to(ROOT)), "PBXFileReference", lastKnownFileType="sourcecode.swift", path=path.name, sourceTree="<group>")
        references.append(ref)
        builds.append(obj("build:" + str(path.relative_to(ROOT)), "PBXBuildFile", fileRef=ref))
    return references, builds


def generate():
    app_refs, app_builds = source_group("LocalDemo")
    test_refs, test_builds = source_group("LocalDemoUITests")
    resources = obj("resources", "PBXFileReference", lastKnownFileType="folder", path="DemoResources", sourceTree="<group>")
    icons = obj("icons", "PBXFileReference", lastKnownFileType="folder.assetcatalog", path="Assets.xcassets", sourceTree="<group>")
    info = obj("info", "PBXFileReference", lastKnownFileType="text.plist.xml", path="Info.plist", sourceTree="<group>")
    app = obj("product", "PBXFileReference", explicitFileType="wrapper.application", path="LocalDemo.app", sourceTree="BUILT_PRODUCTS_DIR", includeInIndex=0)
    tests = obj("test-product", "PBXFileReference", explicitFileType="wrapper.cfbundle", path="LocalDemoUITests.xctest", sourceTree="BUILT_PRODUCTS_DIR", includeInIndex=0)
    group = obj("main-group", "PBXGroup", children=[obj("app-group", "PBXGroup", path="LocalDemo", sourceTree="<group>", children=app_refs + [info, resources, icons]), obj("test-group", "PBXGroup", path="LocalDemoUITests", sourceTree="<group>", children=test_refs), obj("products", "PBXGroup", name="Products", sourceTree="<group>", children=[app, tests])], sourceTree="<group>")
    common = {"IPHONEOS_DEPLOYMENT_TARGET": "18.0", "SDKROOT": "iphoneos", "SWIFT_VERSION": "5.0", "CLANG_ENABLE_MODULES": "YES", "TARGETED_DEVICE_FAMILY": "1", "CODE_SIGN_STYLE": "Manual", "CODE_SIGNING_ALLOWED": "NO", "CODE_SIGNING_REQUIRED": "NO", "CODE_SIGN_IDENTITY": "", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO", "ENABLE_USER_SCRIPT_SANDBOXING": "YES"}
    app_settings = {**common, "PRODUCT_BUNDLE_IDENTIFIER": "com.marton.localdemo", "PRODUCT_NAME": "$(TARGET_NAME)", "INFOPLIST_FILE": "LocalDemo/Info.plist", "GENERATE_INFOPLIST_FILE": "NO", "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"], "CURRENT_PROJECT_VERSION": "1", "MARKETING_VERSION": "1.0", "ENABLE_PREVIEWS": "YES"}
    app_target = obj("app-target", "PBXNativeTarget", name="LocalDemo", productName="LocalDemo", productReference=app, productType="com.apple.product-type.application", buildConfigurationList=configs("app", app_settings), buildPhases=[obj("app-sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=app_builds, runOnlyForDeploymentPostprocessing=0), obj("app-frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0), obj("app-resources", "PBXResourcesBuildPhase", buildActionMask=2147483647, files=[obj("build-resources", "PBXBuildFile", fileRef=resources), obj("build-icons", "PBXBuildFile", fileRef=icons)], runOnlyForDeploymentPostprocessing=0)], buildRules=[], dependencies=[])
    test_settings = {**common, "PRODUCT_BUNDLE_IDENTIFIER": "com.marton.localdemo.uitests", "PRODUCT_NAME": "$(TARGET_NAME)", "GENERATE_INFOPLIST_FILE": "YES", "TEST_TARGET_NAME": "LocalDemo", "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"]}
    proxy = obj("test-proxy", "PBXContainerItemProxy", containerPortal=uid("project"), proxyType=1, remoteGlobalIDString=app_target, remoteInfo="LocalDemo")
    test_target = obj("test-target", "PBXNativeTarget", name="LocalDemoUITests", productName="LocalDemoUITests", productReference=tests, productType="com.apple.product-type.bundle.ui-testing", buildConfigurationList=configs("tests", test_settings), buildPhases=[obj("test-sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=test_builds, runOnlyForDeploymentPostprocessing=0), obj("test-frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)], buildRules=[], dependencies=[obj("test-dependency", "PBXTargetDependency", target=app_target, targetProxy=proxy)])
    project = obj("project", "PBXProject", attributes={"BuildIndependentTargetsInParallel": "YES", "LastUpgradeCheck": "1640", "TargetAttributes": {app_target: {"CreatedOnToolsVersion": "16.4"}, test_target: {"CreatedOnToolsVersion": "16.4", "TestTargetID": app_target}}}, buildConfigurationList=configs("project", {"CLANG_ENABLE_OBJC_ARC": "YES", "ALWAYS_SEARCH_USER_PATHS": "NO"}), compatibilityVersion="Xcode 14.0", developmentRegion="zh-Hans", hasScannedForEncodings=0, knownRegions=["zh-Hans", "en", "Base"], mainGroup=group, productRefGroup=uid("products"), projectDirPath="", projectRoot="", targets=[app_target, test_target])
    PROJECT.mkdir(parents=True, exist_ok=True)
    (PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode({"archiveVersion": 1, "classes": {}, "objectVersion": 56, "objects": objects, "rootObject": project}) + "\n", encoding="utf-8")
    schemes = PROJECT / "xcshareddata/xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    app_ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="LocalDemo.app" BlueprintName="LocalDemo" ReferencedContainer="container:LocalDemo.xcodeproj"/>'
    test_ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="LocalDemoUITests.xctest" BlueprintName="LocalDemoUITests" ReferencedContainer="container:LocalDemo.xcodeproj"/>'
    (schemes / "LocalDemo.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1640" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''', encoding="utf-8")
    print(f"Generated {PROJECT} with {len(app_builds)} app sources and {len(test_builds)} UI test sources")


if __name__ == "__main__":
    generate()
