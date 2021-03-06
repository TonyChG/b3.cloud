#!/bin/bash
# =============================================================================
# Name     : mon.sh
# Function : Start ceph monitor using docker image ceph/daemon
# Usage    : ./mon.sh
#            NETWORK_CIDR=
#            Network where the ceph cluster will be activated
#            Example: 192.168.1.1/24
#            MON_IP=
#            Main monitor ip address
#            Example: 192.168.1.10
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# Date        Who      What
# 11/06/18    tonychg  Created
# =============================================================================

# Needed => Fail to start after remove of /var/lib/ceph
sudo sudo mkdir -p /var/lib/ceph/bootstrap-rbd
sudo sudo chown -R 64045:64045 /var/lib/ceph/bootstrap-rbd

docker ps | grep -q 'ceph-mon' && docker rm -f 'ceph-mon'
docker run -d --net=host \
    --restart always \
    -v /etc/ceph:/etc/ceph \
    -v /var/lib/ceph/:/var/lib/ceph/ \
    -e MON_IP=$MON_IP \
    -e CEPH_PUBLIC_NETWORK=$NETWORK_CIDR \
    --name='ceph-mon' ceph/daemon mon
