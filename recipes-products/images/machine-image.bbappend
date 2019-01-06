# Additional non-open source packages to be put to the root filesystem.
# If product is specified try to include product inc otherwise include base inc.
require ${@get_bblayer_img_inc('wlan', d)}
