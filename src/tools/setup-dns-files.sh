#!/bin/bash
#
# Setup /etc/hosts to resolve hostnames of our containers.
#
# Usage:
#   setup-dns-files.sh
#

pushd $(realpath `dirname "$0"`) &> /dev/null
set -xe

# First remove lines if they exist
sed -i '/master.ipa.test/d' /etc/hosts
sed -i '/master.ldap.test/d' /etc/hosts
sed -i '/dc.samba.test/d' /etc/hosts
sed -i '/client.test/d' /etc/hosts
sed -i '/nfs.test/d' /etc/hosts
sed -i '/kdc.test/d' /etc/hosts
sed -i '/dc.ad.test/d' /etc/hosts
sed -i '/master.ipa2.test/d' /etc/hosts

# Append the lines
echo "172.16.100.10 master.ipa.test" >> /etc/hosts
echo "172.16.100.20 master.ldap.test" >> /etc/hosts
echo "172.16.100.30 dc.samba.test" >> /etc/hosts
echo "172.16.100.40 client.test" >> /etc/hosts
echo "172.16.100.50 nfs.test" >> /etc/hosts
echo "172.16.100.60 kdc.test" >> /etc/hosts
echo "172.16.200.10 dc.ad.test" >> /etc/hosts
echo "172.16.110.10 master.ipa2.test" >> /etc/hosts
