#!/bin/bash
# =============================================================================
# Name     : osd.sh
# Function : Start ceph osd using docker image ceph/daemon
# Usage    : ./osd 
#            PART_SIZE=VALUE
#               ceph partition size in GiB
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# Date        Who      What
# 11/06/18    tonychg  Created
# =============================================================================

part_name="$(lsblk | egrep $PART_SIZE"G" | awk '{print$1}')"
docker ps | grep -q 'ceph-osd' && docker rm -f 'ceph-osd'
docker run -d \
    --net=host \
    --privileged=true \
    --pid=host \
    -v /etc/ceph:/etc/ceph \
    -v /var/lib/ceph/:/var/lib/ceph/ \
    -v /dev/:/dev/ \
    -e OSD_FORCE_ZAP=1 \
    -e OSD_DEVICE="/dev/$part_name" \
    -e OSD_TYPE=disk \
    --name='ceph-osd' \
    --restart=always \
    ceph/daemon osd_ceph_disk
