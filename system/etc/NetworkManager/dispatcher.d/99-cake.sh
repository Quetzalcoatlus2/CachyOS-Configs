#!/bin/sh
if [ "$1" = "wlan0" ] && [ "$2" = "up" ]; then
    /usr/bin/tc qdisc replace dev wlan0 root cake
fi
