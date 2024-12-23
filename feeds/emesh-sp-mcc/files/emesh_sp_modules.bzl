load("//build/bazel_common_rules/dist:dist.bzl", "copy_to_dist_dir")
load("//build/kernel/kleaf:kernel.bzl", "ddk_module")
load("//msm-kernel:target_variants.bzl", "get_all_variants")

_srcs = [
    "sp_api.h",
    "sp.c",
    "sp_hook.c",
    "sp_mapdb.c",
    "sp_mapdb.h",
    "sp_types.h",
]

def define_modules():
    for (t, v) in get_all_variants():
        tv = "{}_{}".format(t, v)
        name = "emesh_sp_{}".format(tv)

        ddk_module(
            name = name,
            srcs = native.glob(_srcs),
            out = "emesh-sp.ko",
            kernel_build = "//msm-kernel:{}".format(tv),
            deps = [
                "//msm-kernel:all_headers",
            ],
        )

        copy_to_dist_dir(
            name = "{}_modules_dist".format(tv),
            data = [":{}".format(name)],
            dist_dir = "out/target/product/{}/dlkm/lib/modules/".format(t),
            flat = True,
            wipe_dist_dir = False,
            allow_duplicate_filenames = False,
            mode_overrides = {"**/*": "644"},
            log = "info",
        )
