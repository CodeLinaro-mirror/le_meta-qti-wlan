fix_miscwifi_service () {
    if [ -f ${WORKDIR}/systemrw-misc-wifi.service ]; then
        sed -i "s#After=systemrw.mount sockets.target#After=systemrw.mount#g" ${WORKDIR}/systemrw-misc-wifi.service
    fi
}
do_install[prefuncs] += "fix_miscwifi_service"
