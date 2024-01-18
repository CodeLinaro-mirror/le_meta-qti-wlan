fix_miscwifi_service () {
    sed -i "s#After=systemrw.mount sockets.target#After=systemrw.mount#g" ${WORKDIR}/systemrw-misc-wifi.service
}
do_install[prefuncs] += "fix_miscwifi_service"
