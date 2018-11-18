#!/bin/bash
# =============================================================================
# Name     : loadimages.sh
# Function :
# Usage    :
# Version  : 1.0.0
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# When        Who      What
# 11/18/18    tonychg
# =============================================================================

docker_images=( \
/home/core/share/images/keepalived.tar.gz \
/home/core/share/images/ceph_daemon.tar.gz \
)

for i in ${docker_images[@]}; do
    echo "Load $i"
    docker load < $i
done
