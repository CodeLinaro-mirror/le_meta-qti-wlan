load("//build/bazel_common_rules/dist:dist.bzl", "copy_to_dist_dir")
load("//build/kernel/kleaf:kernel.bzl", "ddk_module")
load("//msm-kernel:target_variants.bzl", "get_all_variants")

_srcs = [
    "hyfi-multicast/*.h",
    "hyfi-multicast/*.c",
    "hyfi-netfilter/*.h",
    "hyfi-netfilter/*.c",
]

_src_includes = [
    "hyfi-multicast",
    "hyfi-netfilter",
]

def define_modules():
    for (t, v) in get_all_variants():
        tv = "{}_{}".format(t, v)
        name = "hyfi-bridge_{}".format(tv)
        tgt = "target-aarch64_cortex-a53_musl"
        board = "sdx85"

        copts = []
        copts.append("-DHYFI_DISABLE_SSDK_SUPPORT")
        copts.append("-DHYFI_MULTICAST_SUPPORT")
        copts.append("-DDISABLE_APS_HOOKS")
        copts.append("-DHYFI_BRIDGE_EMESH_ENABLE")
        copts.append("-DHYFI_NF_DEBUG_LEVEL=1")
        copts.append("-DHYFI_MC_DEBUG_LEVEL=1")
        copts.append("-Wno-error")

        ddk_module(
            name = name,
            srcs = native.glob(_srcs),
            includes = _src_includes + ["."],
            copts = copts,
            out = "hyfi-bridging.ko",
            kernel_build = "//msm-kernel:{}".format(tv),
            deps = [
                "//msm-kernel:all_headers",
                ":emesh-sp-headers",
                "//build_dir/{}/linux-{}/emesh-sp-mcc-1.0:emesh_sp_{}".format(tgt, board, tv),
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
