#!/bin/bash
# =============================================================================
# Name     : reload.sh
# Function :
# Usage    :
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# Date        Who      What
# 11/05/18    tonychg
# =============================================================================

scripts_path="`dirname $(realpath $0)`"
sshcmd=(ssh -q -i $HOME/.vagrant.d/insecure_private_key -o "StrictHostKeyChecking=no")

hosts=(\
'192.168.4.101' \
'192.168.4.102' \
'192.168.4.103' \
'192.168.4.104' \
'192.168.4.105' \
# '192.168.4.201' \
# '192.168.4.202' \
# '192.168.4.203' \
# '192.168.4.204' \
# '192.168.4.205' \
)

mount_data="sudo mount -a"

UNICAST_PEERS="[$(echo "'${hosts[@]}'" | sed -e 's# #, #g')]"
priority=200

for i in "${hosts[@]}"; do
    start_keepalived="\
        ! [[ -z $(docker ps | grep 'keepalived' ) ]] && docker rm -f keepalived ; \
        docker run -d --name keepalived --restart=always \
        --cap-add=NET_ADMIN --net=host \
        -e KEEPALIVED_VIRTUAL_IPS=192.168.4.100 \
        -e KEEPALIVED_UNICAST_PEERS=\"#PYTHON2BASH:$UNICAST_PEERS\" \
        -e KEEPALIVED_PRIORITY=$priority \
        osixia/keepalived:1.3.5"
    ${sshcmd[@]} core@$i "$start_keepalived"
    priority=$((priority+1))
done

# ${sshcmd[@]} core@192.168.4.101 NETWORK_CIDR="192.168.4.1/24" MONITOR_IP="192.168.4.101" 'bash -s' < $scripts_path/ceph/mon.sh

# for i in "${hosts[@]}"; do
#     ${sshcmd[@]} core@$i "sudo sgdisk -Z /dev/sdb"
# done
