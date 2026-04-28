load("//build/bazel_common_rules/dist:dist.bzl", "copy_to_dist_dir")
load("//build/kernel/kleaf:kernel.bzl", "ddk_module")

_copts = [
    "-Werror",
    "-Wall",
    "-g",
    "-DSP_DEBUG_LEVEL=0",
]

_srcs = [
    "sp.c",
    "sp_hook.c",
    "sp_mapdb.c",
]

def define_module_variants():
    target = "sdxkova"
    variants = ["debug-defconfig", "perf-defconfig"]
    for variant in variants:
        _define_modules(target, variant)

def _define_modules(target, variant):

    ddk_module(
        name = "{}_{}_emesh_sp".format(target, variant),
        out = "emesh-sp.ko",
        srcs = _srcs,
        copts = _copts,
        kernel_build = "//msm-kernel:{}_{}".format(target, variant),
        deps = [
            ":emesh_sp_headers",
            "//msm-kernel:all_headers",
        ],
        visibility = ["//visibility:public"],
    )

    copy_to_dist_dir(
        name = "{}_{}_emesh_sp_module_dist".format(target, variant),
        data = [":{}_{}_emesh_sp".format(target, variant)],
        dist_dir = "out/target/product/{}/dlkm/lib/modules/".format(target),
        flat = True,
        wipe_dist_dir = False,
        allow_duplicate_filenames = False,
        mode_overrides = {"**/*": "644"},
        log = "info",
    )

def define_emesh_sp():
    define_module_variants()
