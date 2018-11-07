#!/bin/bash
# =============================================================================
# Name     : mds.sh
# Function : Start ceph mds using docker image ceph/daemon
# Usage    : ./mds.sh
#            DATA_POOL_PG=VALUE 
#               Ceph data pool pg size
#               https://ceph.com/pgcalc/
#            METADATA_POOL_PG=VALUE 
#               Ceph metadata pg pool size
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# Date        Who      What
# 11/06/18    tonychg  Created
# =============================================================================


docker ps | grep -q 'ceph-mds' && docker rm -f 'ceph-mds'
docker run -d --net=host \
    --name ceph-mds \
    --restart always \
    -v /var/lib/ceph/:/var/lib/ceph/ \
    -v /etc/ceph:/etc/ceph \
    -e CEPHFS_CREATE=1 \
    -e CEPHFS_DATA_POOL_PG=$DATA_POOL_PG \
    -e CEPHFS_METADATA_POOL_PG=$METADATA_POOL_PG \
    ceph/daemon mds
