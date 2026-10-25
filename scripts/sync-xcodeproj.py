#!/usr/bin/env python3
"""Generates apps/macos/Kollio.xcodeproj.

The Xcode project is a thin wrapper: it builds a macOS app target so Cmd+R and
the debugger work, while the domain (KollioCore) and the backend (KollioServer)
stay SwiftPM packages, which remain the single source of truth for them.

The app target compiles the same sources as the KollioApp package. That
duplication is deliberate and is the only one in the repository: the file list is
generated from disk by this script, never edited by hand.

    ./scripts/sync-xcodeproj.py
"""

import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_SOURCES = os.path.join(ROOT, "packages/KollioApp/Sources/KollioApp")
APP_RESOURCES = os.path.join(APP_SOURCES, "Resources")
PROJECT_DIR = os.path.join(ROOT, "apps/macos")
PROJECT_NAME = "Kollio"
INFO_PLIST = os.path.join(PROJECT_DIR, "Info.plist")
PACKAGE_DIR = os.path.join(PROJECT_DIR, "Kollio.xcodeproj")
RELATIVE_APP_SOURCES = "packages/KollioApp/Sources/KollioApp"
# File references are resolved from the project directory, not from the
# repository root.
APP_SOURCE_PREFIX = os.path.relpath(
    os.path.join(ROOT, RELATIVE_APP_SOURCES), PROJECT_DIR
)


def uid(*parts):
    """A stable 24 hex character object id derived from the path."""
    digest = hashlib.md5("::".join(parts).encode()).hexdigest()
    return digest[:24].upper()


def file_uid(relative_path):
    """The object id of a source file, from one place.

    A group child, a `PBXFileReference` and a `PBXBuildFile` must all agree on this
    id, and the first version of this script computed it in three slightly
    different ways. The groups then pointed at 24 objects the project never defined,
    which is what Xcode was reporting as "file format integrity issues": the build
    still worked, because the build phases resolve through their own references, so
    the damage was confined to the navigator and to Xcode's opinion of the file.
    """
    return uid("file", os.path.join(RELATIVE_APP_SOURCES, relative_path))


def collect(root, extensions):
    found = []
    for base, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for name in sorted(files):
            if os.path.splitext(name)[1] in extensions:
                found.append(os.path.relpath(os.path.join(base, name), root))
    return found


def group_tree(paths):
    """Nested groups mirroring the directory layout, for the navigator."""
    tree = {}
    for path in paths:
        parts = path.split(os.sep)
        node = tree
        for part in parts[:-1]:
            node = node.setdefault(part, {})
        node.setdefault("", []).append(path)
    return tree


def emit_group_defs(tree, ids_parent="", path_prefix=None):
    """Full PBXGroup definitions, written at the top level of `objects`.

    A group carries a `name` and no `path`: the file references themselves resolve
    from `SOURCE_ROOT` with a path relative to the project directory, so the
    navigator shows the short folder name and the disk resolution does not depend
    on where the group sits in the tree.
    """
    lines = []
    for name in sorted(tree.keys()):
        if name == "":
            continue
        group_id = uid("group", os.path.join(ids_parent, name))
        full_path = os.path.join(path_prefix, name) if path_prefix else name
        lines.append("\t\t%s /* %s */ = {" % (group_id, name))
        lines.append("\t\t\tisa = PBXGroup;")
        lines.append("\t\t\tchildren = (")
        for child in child_references(tree[name], os.path.join(ids_parent, name)):
            lines.append("\t\t\t\t" + child)
        lines.append("\t\t\t);")
        lines.append("\t\t\tname = %s;" % name)
        lines.append("\t\t\tsourceTree = \"<group>\";")
        lines.append("\t\t};")
        lines.extend(emit_group_defs(
            tree[name],
            ids_parent=os.path.join(ids_parent, name),
            path_prefix=full_path,
        ))
    return lines


def child_references(node, parent):
    """A group's children are references only, never inline definitions.

    The file paths in the tree are already relative to the app source root, so they
    are looked up as they are. Prefixing them with the group's own path a second
    time is what made every group child point at an object the project never
    defined: 23 sources and one resource, all of them dangling, which Xcode reports
    as a file format integrity issue while the build itself carries on working
    because the build phases resolve through their own references.
    """
    references = []
    for name in sorted(node.keys()):
        if name == "":
            for file_path in sorted(node[name]):
                references.append("%s /* %s */," % (
                    file_uid(file_path),
                    os.path.basename(file_path),
                ))
        else:
            references.append("%s /* %s */," % (uid("group", os.path.join(parent, name)), name))
    return references


def emit_file_ref(relative_path):
    file_id = file_uid(relative_path)
    name = os.path.basename(relative_path)
    extension = os.path.splitext(name)[1]
    file_type = {
        ".swift": "sourcecode.swift",
        ".xcstrings": "text.json.xcstrings",
        ".plist": "text.plist.xml",
        ".md": "net.daringfireball.markdown",
        ".json": "text.json",
        ".sh": "text.script.sh",
        ".yaml": "text.yaml",
    }.get(extension, "text")
    full_path = os.path.join(APP_SOURCE_PREFIX, relative_path)
    return "\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = %s; name = %s; path = %s; sourceTree = SOURCE_ROOT; };" % (
        file_id, name, file_type, name, full_path)


def build_file(relative_path):
    file_id = file_uid(relative_path)
    return "\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };" % (
        uid("build", relative_path),
        os.path.basename(relative_path),
        file_id,
        os.path.basename(relative_path),
    )


def build_resource(relative_path):
    file_id = file_uid(relative_path)
    return "\t\t%s /* %s in Resources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };" % (
        uid("resource", relative_path),
        os.path.basename(relative_path),
        file_id,
        os.path.basename(relative_path),
    )


def main():
    sources = collect(APP_SOURCES, {".swift"})
    # Resource paths are kept relative to the source root too, so the group
    # layout is identical for code and resources.
    # Both lists are expressed relative to the app source root, so one file path
    # means one object id everywhere it appears.
    resources = [
        os.path.join("Resources", path)
        for path in collect(APP_RESOURCES, {".xcstrings"})
    ]
    if not sources:
        sys.exit("No Swift sources found under %s" % APP_SOURCES)

    os.makedirs(os.path.join(PACKAGE_DIR, "xcshareddata/xcschemes"), exist_ok=True)
    if not os.path.exists(INFO_PLIST):
        sys.exit("Missing %s" % INFO_PLIST)

    all_files = sources + resources
    tree = group_tree(all_files)

    project_id = uid("project")
    target_id = uid("target", PROJECT_NAME)
    product_id = uid("product")
    main_group = uid("group", "main")
    products_group = uid("group", "Products")
    info_ref = uid("file", "Info.plist")
    info_build = uid("build", "Info.plist")
    core_package = uid("package", "KollioCore")
    core_product_dep = uid("packageproduct", "KollioCore")
    core_build = uid("build", "package", "KollioCore")
    sources_phase = uid("phase", "sources")
    resources_phase = uid("phase", "resources")
    frameworks_phase = uid("phase", "frameworks")
    project_config_list = uid("configlist", "project")
    target_config_list = uid("configlist", "target")

    out = []
    add = out.append
    add("// !$*UTF8*$!")
    add("{")
    add("\tarchiveVersion = 1;")
    add("\tclasses = {")
    add("\t};")
    add("\tobjectVersion = 77;")
    add("\tobjects = {")

    add("\n/* Begin PBXBuildFile section */")
    for path in sources:
        add(build_file(path))
    for path in resources:
        add(build_resource(path))
    add("\t\t%s /* KollioCore in Frameworks */ = {isa = PBXBuildFile; productRef = %s /* KollioCore */; };" % (core_build, core_product_dep))
    add("\t\t%s /* Info.plist in Resources */ = {isa = PBXBuildFile; fileRef = %s /* Info.plist */; };" % (info_build, info_ref))
    add("/* End PBXBuildFile section */")

    add("\n/* Begin PBXFileReference section */")
    for path in all_files:
        add(emit_file_ref(path))
    add('\t\t%s /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };' % info_ref)
    add('\t\t%s /* Kollio.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Kollio.app; sourceTree = BUILT_PRODUCTS_DIR; };' % product_id)
    add("/* End PBXFileReference section */")

    add("\n/* Begin PBXFrameworksBuildPhase section */")
    add("\t\t%s /* Frameworks */ = {" % frameworks_phase)
    add("\t\t\tisa = PBXFrameworksBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    add("\t\t\t\t%s /* KollioCore in Frameworks */," % core_build)
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXFrameworksBuildPhase section */")

    add("\n/* Begin PBXGroup section */")
    add("\t\t%s = {" % main_group)
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    for child in child_references(tree, ""):
        add("\t\t\t\t" + child)
    add("\t\t\t\t%s /* Info.plist */," % info_ref)
    add("\t\t\t\t%s /* Products */," % products_group)
    add("\t\t\t);")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")
    add("\t\t%s /* Products */ = {" % products_group)
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add("\t\t\t\t%s /* Kollio.app */," % product_id)
    add("\t\t\t);")
    add("\t\t\tname = Products;")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")
    for line in emit_group_defs(tree, path_prefix=RELATIVE_APP_SOURCES):
        add(line)
    add("/* End PBXGroup section */")

    add("\n/* Begin PBXNativeTarget section */")
    add("\t\t%s /* Kollio */ = {" % target_id)
    add("\t\t\tisa = PBXNativeTarget;")
    add("\t\t\tbuildConfigurationList = %s;" % target_config_list)
    add("\t\t\tbuildPhases = (")
    add("\t\t\t\t%s /* Sources */," % sources_phase)
    add("\t\t\t\t%s /* Frameworks */," % frameworks_phase)
    add("\t\t\t\t%s /* Resources */," % resources_phase)
    add("\t\t\t);")
    add("\t\t\tbuildRules = (")
    add("\t\t\t);")
    add("\t\t\tdependencies = (")
    add("\t\t\t);")
    add("\t\t\tname = Kollio;")
    add("\t\t\tpackageProductDependencies = (")
    add("\t\t\t\t%s /* KollioCore */," % core_product_dep)
    add("\t\t\t);")
    add("\t\t\tproductName = Kollio;")
    add("\t\t\tproductReference = %s /* Kollio.app */;" % product_id)
    add("\t\t\tproductType = \"com.apple.product-type.application\";")
    add("\t\t};")
    add("/* End PBXNativeTarget section */")

    add("\n/* Begin PBXProject section */")
    add("\t\t%s /* Project object */ = {" % project_id)
    add("\t\t\tisa = PBXProject;")
    add("\t\t\tattributes = {")
    add("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    add("\t\t\t\tLastSwiftUpdateCheck = 2700;")
    add("\t\t\t\tLastUpgradeCheck = 2700;")
    add("\t\t\t\tTargetAttributes = {")
    add("\t\t\t\t\t%s = {" % target_id)
    add("\t\t\t\t\t\tCreatedOnToolsVersion = 27.0;")
    add("\t\t\t\t\t};")
    add("\t\t\t\t};")
    add("\t\t\t};")
    add("\t\t\tbuildConfigurationList = %s;" % project_config_list)
    add("\t\t\tcompatibilityVersion = \"Xcode 15.0\";")
    add("\t\t\tdevelopmentRegion = fr;")
    add("\t\t\thasScannedForEncodings = 0;")
    add("\t\t\tknownRegions = (fr, en, Base);")
    add("\t\t\tmainGroup = %s;" % main_group)
    add("\t\t\tminimizedProjectReferenceProxies = 1;")
    add("\t\t\tpackageReferences = (")
    add("\t\t\t\t%s /* XCLocalSwiftPackageReference \"../packages/KollioCore\" */," % core_package)
    add("\t\t\t);")
    add("\t\t\tproductRefGroup = %s /* Products */;" % products_group)
    add("\t\t\tprojectDirPath = \"\";")
    add("\t\t\tprojectRoot = \"\";")
    add("\t\t\ttargets = (")
    add("\t\t\t\t%s /* Kollio */," % target_id)
    add("\t\t\t);")
    add("\t\t};")
    add("/* End PBXProject section */")

    add("\n/* Begin PBXResourcesBuildPhase section */")
    add("\t\t%s /* Resources */ = {" % resources_phase)
    add("\t\t\tisa = PBXResourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    for path in resources:
        add("\t\t\t\t%s /* %s in Resources */," % (uid("resource", path), os.path.basename(path)))
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXResourcesBuildPhase section */")

    add("\n/* Begin PBXSourcesBuildPhase section */")
    add("\t\t%s /* Sources */ = {" % sources_phase)
    add("\t\t\tisa = PBXSourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    for path in sources:
        add("\t\t\t\t%s /* %s in Sources */," % (uid("build", path), os.path.basename(path)))
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXSourcesBuildPhase section */")

    add("\n/* Begin XCBuildConfiguration section */")
    for name in ("Debug", "Release"):
        config_id = uid("config", "project", name)
        add("\t\t%s /* %s */ = {" % (config_id, name))
        add("\t\t\tisa = XCBuildConfiguration;")
        add("\t\t\tbuildSettings = {")
        add("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
        add("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
        add("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
        add("\t\t\t\tCOPY_PHASE_STRIP = NO;")
        if name == "Debug":
            add("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
            # The debug dylib indirection does not pick up the Swift entry
            # point of a package-shaped app target, so Debug links directly.
            add("\t\t\t\tENABLE_DEBUG_DYLIB = NO;")
            add("\t\t\t\tENABLE_TESTABILITY = YES;")
            add("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
            add("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
            add("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
            add("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";")
            add("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
        else:
            add("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
            add("\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
            add("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
        add("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 26.0;")
        add("\t\t\t\tSDKROOT = macosx;")
        add("\t\t\t\tSWIFT_VERSION = 6.0;")
        add("\t\t\t};")
        add("\t\t\tname = %s;" % name)
        add("\t\t};")
    for name in ("Debug", "Release"):
        config_id = uid("config", "target", name)
        add("\t\t%s /* %s */ = {" % (config_id, name))
        add("\t\t\tisa = XCBuildConfiguration;")
        add("\t\t\tbuildSettings = {")
        add("\t\t\t\tCODE_SIGN_IDENTITY = \"-\";")
        add("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
        add("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
        add("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
        add("\t\t\t\tENABLE_HARDENED_RUNTIME = NO;")
        add("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
        add("\t\t\t\tINFOPLIST_FILE = Info.plist;")
        add("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\"$(inherited)\", \"@executable_path/../Frameworks\");")
        add("\t\t\t\tMARKETING_VERSION = 0.1.0;")
        add("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = dev.kollio.app;")
        add("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
        add("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
        add("\t\t\t};")
        add("\t\t\tname = %s;" % name)
        add("\t\t};")
    add("/* End XCBuildConfiguration section */")

    add("\n/* Begin XCConfigurationList section */")
    for scope, list_id in (("project", project_config_list), ("target", target_config_list)):
        add("\t\t%s /* Build configuration list for %s */ = {" % (list_id, "PBXProject \"" + PROJECT_NAME + "\"" if scope == "project" else "PBXNativeTarget \"" + PROJECT_NAME + "\""))
        add("\t\t\tisa = XCConfigurationList;")
        add("\t\t\tbuildConfigurations = (")
        for name in ("Debug", "Release"):
            add("\t\t\t\t%s /* %s */," % (uid("config", scope, name), name))
        add("\t\t\t);")
        add("\t\t\tdefaultConfigurationIsVisible = 0;")
        add("\t\t\tdefaultConfigurationName = Release;")
        add("\t\t};")
    add("/* End XCConfigurationList section */")

    add("\n/* Begin XCLocalSwiftPackageReference section */")
    add('\t\t%s /* XCLocalSwiftPackageReference "../packages/KollioCore" */ = {' % core_package)
    add("\t\t\tisa = XCLocalSwiftPackageReference;")
    add("\t\t\trelativePath = ../../packages/KollioCore;")
    add("\t\t};")
    add("/* End XCLocalSwiftPackageReference section */")

    add("\n/* Begin XCSwiftPackageProductDependency section */")
    add("\t\t%s /* KollioCore */ = {" % core_product_dep)
    add("\t\t\tisa = XCSwiftPackageProductDependency;")
    add("\t\t\tpackage = %s /* XCLocalSwiftPackageReference \"../packages/KollioCore\" */;" % core_package)
    add("\t\t\tproductName = KollioCore;")
    add("\t\t};")
    add("/* End XCSwiftPackageProductDependency section */")

    add("\t};")
    add("\trootObject = %s /* Project object */;" % project_id)
    add("}")

    with open(os.path.join(PACKAGE_DIR, "project.pbxproj"), "w") as handle:
        handle.write("\n".join(out) + "\n")

    # A shared scheme, so Cmd+R and Cmd+U work in any window that opens it.
    scheme = SCHEME % {
        "target": target_id,
        "name": PROJECT_NAME,
        "bundle": "dev.kollio.app",
    }
    with open(os.path.join(PACKAGE_DIR, "xcshareddata/xcschemes/%s.xcscheme" % PROJECT_NAME), "w") as handle:
        handle.write(scheme)

    print("Generated %s with %d sources and %d resources" % (PACKAGE_DIR, len(sources), len(resources)))


SCHEME = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2700" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "%(target)s"
               BuildableName = "%(name)s.app"
               BlueprintName = "%(name)s"
               ReferencedContainer = "container:%(name)s.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "%(target)s"
            BuildableName = "%(name)s.app"
            BlueprintName = "%(name)s"
            ReferencedContainer = "container:%(name)s.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "%(target)s"
            BuildableName = "%(name)s.app"
            BlueprintName = "%(name)s"
            ReferencedContainer = "container:%(name)s.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


if __name__ == "__main__":
    main()
