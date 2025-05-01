load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@build_bazel_rules_apple//apple:macos.bzl", "macos_application")
load("@build_bazel_rules_apple//apple:versioning.bzl", "apple_bundle_version")
load("@build_bazel_rules_swift//mixed_language:mixed_language_library.bzl", "mixed_language_library")
load("@build_bazel_rules_swift//swift:swift_library.bzl", "swift_library")


objc_library(
    name="AuthOpenWrapper",
    srcs=[
        "authopenwrapper.m"
    ],
    hdrs=[
        "authopenwrapper.h"
    ],
    module_name="AuthOpenWrapper",
    alwayslink=1,
)

swift_library(
    name = "Gooey_Writer.sources",
    srcs = glob(["*.swift"]),
    deps = [
        ":AuthOpenWrapper",
        "@swiftpkg_citadel//:Citadel",
        "@swiftpkg_swift_collections//:OrderedCollections",
    ]
)


mixed_language_library(
    name = "Gooey_Writer.sources_old",
    clang_srcs = ["authopenwrapper.mm"],
    textual_hdrs = ["authopenwrapper.h"],
    swift_srcs = glob(["*.swift"]),
    deps = [
        "@swiftpkg_citadel//:Citadel",
        "@swiftpkg_swift_collections//:OrderedCollections",
    ],
    swift_copts = [
        "-import-objc-header",
        "Gooey Writer-Bridging-Header.h",
    ]
)

macos_application(
    name="Gooey_Writer",
    bundle_id="cz.lukasbrabec.Gooey-Writer",
    entitlements="Gooey_Writer.entitlements",
    app_icons = ["Assets.xcassets"],
    minimum_os_version = "14.4",
    deps = [":AuthOpenWrapper", ":Gooey_Writer.sources"],
    infoplists = [":Info.plist"]
)