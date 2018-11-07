#!/bin/bash
# =============================================================================
# Name     : mgr.sh
# Function : Start ceph manager using docker image ceph/daemon
# Usage    : ./mgr.sh
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# Date        Who      What
# 11/06/18    tonychg  Created
# =============================================================================

docker ps | grep -q 'ceph-mgr' && docker rm -f 'ceph-mgr'
docker run -d --net=host \
    --privileged=true \
    --pid=host \
    -v /etc/ceph:/etc/ceph \
    -v /var/lib/ceph/:/var/lib/ceph/ \
    --name="ceph-mgr" \
    --restart=always \
    ceph/daemon mgr
