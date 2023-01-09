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
        return 0
    fi
    if [ $2 -eq 0 ]; then
        echo 0
        return 0
    fi
    last=`stat -c %Y $1`
    now=`date +%s`
    since=$(($now - $last))
    if [ $since -ge $2 ]; then
        echo -1
    else
        echo $(($2 - $since))
    fi
    return 0
}
wait_service_running() {
    for i in `seq 1 ${3:-20}`
    do
        STATUS='none'
        [ -f /etc/clash/status/$1 ] && STATUS=`cat /etc/clash/status/$1`
        echolog "[wait_service_running] '$1' status is '$STATUS'"
        if [ "$STATUS" == "running" ];then
            return 0
        fi
        if [ "$STATUS" == "error" ];then
            return 1
        fi
        sleep ${2:-0.5}
    done
}
export -f echolog
export -f echoerr
export -f setroute
export -f unsetroute
export -f file_expired
export -f wait_service_running