#!/bin/bash
#
# Setup host DNS to forward all *.test queries to sssd-ci DNS server.
#
# Usage:
#   setup-dns.sh
#

pushd $(realpath `dirname "$0"`) &> /dev/null
set -xe

cp ../../data/configs/nm_enable_dnsmasq.conf /etc/NetworkManager/conf.d/
cp ../../data/configs/nm_zone_test.conf /etc/NetworkManager/dnsmasq.d/
systemctl disable --now systemd-resolved
rm -f /etc/resolv.conf
systemctl reload NetworkManager
