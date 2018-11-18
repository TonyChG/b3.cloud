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

docker_images=$(find /home/core/share/images -type f -name "*.tar.gz")

for i in ${docker_images[@]}; do
    echo "Load $i"
    docker load < $i
done
