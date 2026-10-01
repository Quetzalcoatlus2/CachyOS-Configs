#!/bin/sh
case "$1/$2" in
  pre/hibernate|pre/suspend-then-hibernate)
    swapoff /dev/zram0
    ;;
  post/hibernate|post/suspend-then-hibernate)
    swapon /dev/zram0 -p 100
    ;;
esac
