#!/usr/local/bin/bash
export _lan="192.168.11.0/24"
declare -A LAN
declare -A LAN_BINARY
LAN_BINARY["address"]=$(command ipcalc $_lan | grep Address | awk '{print $3$4}')
LAN_BINARY["netmask"]=$(command ipcalc $_lan | grep Netmask | awk '{print $3$4}')
LAN_BINARY["network"]=$(command ipcalc $_lan | grep Network | awk '{print $3$4}')
LAN_BINARY["broadcast"]=$(command ipcalc $_lan | grep Broadcast | awk '{print $3$4}')
LAN_BINARY["hostmin"]=$(command ipcalc $_lan | grep HostMin | awk '{print $3$4}')
LAN_BINARY["hostmax"]=$(command ipcalc $_lan | grep HostMax | awk '{print $3$4}')

LAN["address"]=$(command ipcalc $_lan | grep Address | awk '{print $2}')
LAN["netmask"]=$(command ipcalc $_lan | grep Netmask | awk '{print $2}')
LAN["network"]=$(command ipcalc $_lan | grep Network | awk '{print $2}')
LAN["broadcast"]=$(command ipcalc $_lan | grep Broadcast | awk '{print $2}')
LAN["hostmin"]=$(command ipcalc $_lan | grep HostMin | awk '{print $2}')
LAN["hostmax"]=$(command ipcalc $_lan | grep HostMax | awk '{print $2}')
LAN["hosts"]=$(command ipcalc $_lan | grep Hosts | awk '{print $2}')
export LAN LAN_BINARY
export ROUTER=polaris.home
export DNS=$ROUTER
export SWITCH=alphacentauri.home
export ROUTER_DISK=/opt
export CONF_DIR=/opt/etc
export DNS_CONF=${CONF_DIR}/dnsmasq.conf

function router::uptime() {
    ssh $ROUTER 2>/dev/null uptime
}

function router::dns::restart() {
    ssh $ROUTER 2>/dev/null "$ROUTER_DISK/admin/watch-dns.sh"
}

function router::dns::log() {
    ssh $ROUTER 2>/dev/null "tail -f $ROUTER_DISK/admin/dnsmasq.log"
}

function router::dns::zone() {
    ssh $ROUTER 2>/dev/null "cat $ROUTER_DISK/etc/dnsmasq.conf |grep -v '#' | grep -v '^$' |sort" | egrep '(address|dhcp-host)'
}

function router::dns::edit() {
    ssh $ROUTER 2>/dev/null "vi $ROUTER_DISK/etc/dnsmasq.conf"
}