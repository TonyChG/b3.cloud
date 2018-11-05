#!/bin/bash
# =============================================================================
# Name     : deploy_ceph.sh
# Function : Deploy on ceph on swarm cluster using ssh and docker
# Usage    : ./deploy_ceph.sh [--revert]
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# Date        Who      What
# 11/04/18    tonychg  Created
# =============================================================================

network_cidr="192.168.4.1/24"
master="192.168.4.101"
baseuser="core"
ssh_privkey="$HOME/.vagrant.d/insecure_private_key"

# Host by ceph entities
managers=(\
'192.168.4.101' \
'192.168.4.102' \
'192.168.4.103' \
)

monitors=(\
'192.168.4.101' \
'192.168.4.102' \
'192.168.4.103' \
)

hosts=(\
'192.168.4.101' \
'192.168.4.102' \
'192.168.4.103' \
'192.168.4.104' \
'192.168.4.105' \
)

function fatal {
    if [[ $? -ne 0 ]]; then
        >&2 echo -e "$1"
        exit -1
    fi
}

# Wrap ssh commands
sshcmd=(ssh -q -i $ssh_privkey -o "StrictHostKeyChecking=no")
scpcmd=(scp -q -i $ssh_privkey -o "StrictHostKeyChecking=no")


# Revert all operations
function revert {
    for h in ${hosts[@]}; do
        shared_disk=$(${sshcmd[@]} $baseuser@$h "sudo lsblk | egrep '8G' | awk '{print\$1}'")
        ${sshcmd[@]} $baseuser@$h "sudo wipefs -af /dev/$shared_disk"
        ${sshcmd[@]} $baseuser@$h "\
            ! [[ -z \$(docker ps -aq) ]] && docker rm -f \$(docker ps -aq)"
        ${sshcmd[@]} $baseuser@$h "\
            sudo rm -rfv ceph.tar.gz /var/lib/ceph /etc/ceph /etc/fstab"
    done
    exit 0
}

# Reverting on --revert
[[ $1 == '--revert' ]] && revert


# Start ceph master
${sshcmd[@]} $baseuser@$master "\
    docker run -d --net=host \
    --restart always \
    -v /etc/ceph:/etc/ceph \
    -v /var/lib/ceph/:/var/lib/ceph/ \
    -e MON_IP=$master \
    -e CEPH_PUBLIC_NETWORK=$network_cidr \
    --name=\"ceph-mon\" \
    ceph/daemon mon"

fatal "Fail to init ceph root manager"

# Wait starting of the ceph master
>/dev/null 2>&1 ${sshcmd[@]} $baseuser@$master "stat /etc/ceph/ceph.mon.keyring"
while [[ $? -ne 0 ]]; do
    echo "Wait starting of the master ..." ; sleep 1
    >/dev/null 2>&1 ${sshcmd[@]} $baseuser@$master "stat /etc/ceph/ceph.mon.keyring"
done

# Copy ceph keyring to all nodes
${sshcmd[@]} $baseuser@$master "sudo tar cPfz ceph.tar.gz /etc/ceph"
${scpcmd[@]} $baseuser@$master:ceph.tar.gz /tmp/ceph.tar.gz

exclude_master=("${hosts[@]:1}")

for h in "${exclude_master[@]}"; do
    ${scpcmd[@]} /tmp/ceph.tar.gz $baseuser@$h:ceph.tar.gz
    ${sshcmd[@]} $baseuser@$h "sudo tar xPfz ceph.tar.gz -C /"
    echo -e "Copy /etc/ceph to $h"
done

exclude_master=("${monitors[@]:1}")

# Add monitors without master
for h in "${exclude_master[@]}"; do
    echo "Add $h to cluster as monitor"
    ${sshcmd[@]} $baseuser@$h "\
        docker run -d --net=host \
        --restart always \
        -v /etc/ceph:/etc/ceph \
        -v /var/lib/ceph/:/var/lib/ceph/ \
        -e MON_IP=$h \
        -e CEPH_PUBLIC_NETWORK=$network_cidr \
        --name='ceph-mon' ceph/daemon mon"
done

# Add managers
for h in "${managers[@]}"; do
    echo "Add $h to cluster as manager"
    ${sshcmd[@]} $baseuser@$h "\
        docker run -d --net=host \
        --privileged=true \
        --pid=host \
        -v /etc/ceph:/etc/ceph \
        -v /var/lib/ceph/:/var/lib/ceph/ \
        --name=\"ceph-mgr\" \
        --restart=always \
        ceph/daemon mgr"
done

# Get ceph keyring
${sshcmd[@]} $baseuser@$master "\
docker exec ceph-mon ceph auth get client.bootstrap-osd" > /tmp/ceph.keyring

# Start ceph OSD on all nodes
for h in "${hosts[@]}"; do
    ${scpcmd[@]} /tmp/ceph.keyring $baseuser@$h:ceph.keyring
    ${sshcmd[@]} $baseuser@$h "\
        sudo mkdir -p /var/lib/ceph/bootstrap-osd && \
        sudo mv -v ceph.keyring /var/lib/ceph/bootstrap-osd/ceph.keyring"
    echo "Copy ceph.keyring to $h"
    shared_disk=$(${sshcmd[@]} $baseuser@$h "sudo lsblk | egrep '8G' | awk '{print\$1}'")
    ${sshcmd[@]} $baseuser@$h "docker run -d \
        --net=host \
        --privileged=true \
        --pid=host \
        -v /etc/ceph:/etc/ceph \
        -v /var/lib/ceph/:/var/lib/ceph/ \
        -v /dev/:/dev/ \
        -e OSD_FORCE_ZAP=1 \
        -e OSD_DEVICE='/dev/$shared_disk' \
        -e OSD_TYPE=disk \
        --name='ceph-osd' \
        --restart=always \
        ceph/daemon osd_ceph_disk"
    echo "Start OSD on $h"
done

# Start ceph MDS on all nodes
for h in "${hosts[@]}"; do
    ${sshcmd[@]} $baseuser@$h "docker run -d \
        --net=host \
        --name ceph-mds \
        --restart always \
        -v /var/lib/ceph/:/var/lib/ceph/ \
        -v /etc/ceph:/etc/ceph \
        -e CEPHFS_CREATE=1 \
        -e CEPHFS_DATA_POOL_PG=128 \
        -e CEPHFS_METADATA_POOL_PG=256 \
        ceph/daemon mds"
    echo "Start MDS on $h"
done


# Configure ceph pool
${sshcmd[@]} $baseuser@$master "docker exec \
    ceph-mon ceph osd pool set cephfs_data size 2"
# ${sshcmd[@]} $baseuser@$master "docker exec \
#     ceph-mon ceph osd pool set cephfs_metadata size 2"
${sshcmd[@]} $baseuser@$master "docker exec \
    ceph-mon ceph osd set nodeep-scrub"

# Connect to master to generate token
token=$(\
    ${sshcmd[@]} $baseuser@$master "docker exec ceph-mon \
    ceph auth get-or-create client.dockerswarm osd 'allow rw' mon 'allow r' mds 'allow' \
    | grep 'key' \
    | sed -e 's#\tkey \= ##g'")
echo "Generate new token for all nodes: $token"

# Configure disks
manager_ips=$(echo -n "${managers[@]}" | sed -e 's# #,#g')
for h in "${hosts[@]}"; do
    echo "Configure disk on $h"
    ${sshcmd[@]} $baseuser@$h "sudo su -c \
'echo -e \"$manager_ips:6789:/\t/data/\tceph\tname=dockerswarm,secret=$token,noatime,_netdev 0 2\" > /etc/fstab'"
    echo "Push disk config to fstab"
    ${sshcmd[@]} $baseuser@$h "sudo mkdir -p /data"
done
