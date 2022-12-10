#!/usr/bin/env bash
export LOCAL_IP="`ip a | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' |head -n 1`"
echolog() {
    echo -e "\033[32m[chislash log]\033[0m" $*
}
echoerr() {
    echo -e "\033[31m[chislash err]\033[0m" $*
}
setroute() {
    /transparent_proxy/tproxy.start
    if [ "$IPV6_PROXY" == "1" ]; then
        /transparent_proxy/tproxy.start ipv6
    fi
}
unsetroute() {
    /transparent_proxy/tproxy.stop
    if [ "$IPV6_PROXY" == "1" ]; then
        /transparent_proxy/tproxy.stop ipv6
    fi
}
file_expired() {
    if [ ! -f "$1" ]; then
        echo -1
        exit 0
    fi
    if [ $2 -eq 0 ]; then
        echo 0
        exit 0
    fi
    last=`stat -c %Y $1`
    now=`date +%s`
    since=$(($now - $last))
    if [ $since -ge $2 ]; then
        echo -1
    else
        echo $(($2 - $since))
    fi
    exit 0
}
export -f echolog
export -f echoerr
export -f setroute
export -f unsetroute
export -f file_expired