#!/bin/bash
# =============================================================================
# Name     : deploy_ceph.sh
# Function : Deploy on ceph on swarm cluster using ssh and docker
# Usage    : ./deploy_ceph.sh [--revert]
#            --pull-images
#            --managers 
#            --monitors 
#            --osd 
#            --mds 
#            --configure 
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# Date        Who      What
# 11/04/18    tonychg  Created
# =============================================================================

# Params
REVERT_MODE=false
MONITORS=false
MANAGERS=false
OSD=false
MDS=false
CONFIGURE=false
PULL_IMAGES=false

# Ceph configs
network_cidr="192.168.4.1/24"
master="192.168.4.101"
baseuser="core"
part_size="8"
ceph_image="ceph/daemon"
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
'192.168.4.201' \
'192.168.4.202' \
'192.168.4.203' \
'192.168.4.204' \
'192.168.4.205' \
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

scripts_path="`dirname $(realpath $0)`"

while ! [[ -z $1 ]]; do
    LABEL=$(echo $1 | awk -F= '{print $1}')
    VALUE=$(echo $1 | awk -F= '{print $2}')
    case $LABEL in
        --revert|-r)
            REVERT_MODE=true ;;
        --configure)
            CONFIGURE=true   ;;
        --monitors)
            MONITORS=true    ;;
        --managers)
            MANAGERS=true    ;;
        --mds)
            MDS=true         ;;
        --osd)
            OSD=true         ;;
        --pull-images)
            PULL_IMAGES=true ;;
        --all)
            MONITORS=true
            MANAGERS=true
            MDS=true
            OSD=true
            ;;
        *)
            fatal "Unknow options: %s" $LABEL
            usage
            ;;
    esac
    shift
done

# Revert all operations
if $REVERT_MODE ; then
    echo "[[ REVERTING ]]"
    for h in ${hosts[@]}; do
        shared_disk=$(${sshcmd[@]} $baseuser@$h "lsblk | egrep $part_size\"G\" | awk '{print\$1}'")
        ${sshcmd[@]} $baseuser@$h "sudo wipefs -af /dev/$shared_disk"
        ${sshcmd[@]} $baseuser@$h "\
            ! [[ -z \$(docker ps -aq) ]] && docker rm -f \$(docker ps -aq)"
        ${sshcmd[@]} $baseuser@$h "\
            sudo rm -rfv ceph.tar.gz /var/lib/ceph /etc/ceph /etc/fstab"
    done
    exit 0
fi

if $PULL_IMAGES ; then
    for h in ${hosts[@]}; do
        ${sshcmd[@]} $baseuser@$h "docker pull $ceph_image"
    done
fi

# Start ceph master
if $MONITORS ; then
    echo "[[ CEPH MONITORS ]]"
    # Start ceph master
    ${sshcmd[@]} $baseuser@$master \
        NETWORK_CIDR=$network_cidr \
        MON_IP=$master \
        "bash -s" < $scripts_path/ceph/mon.sh
    fatal "Fail to init ceph root manager"

    # Wait starting of the ceph master
    echo "Waiting start of the master ..." ; sleep 1
    >/dev/null 2>&1 ${sshcmd[@]} $baseuser@$master "docker exec ceph-mon ceph status"

    # Get ceph config from master
    ${sshcmd[@]} $baseuser@$master "sudo tar cPfz ceph.tar.gz /etc/ceph"
    ${scpcmd[@]} $baseuser@$master:ceph.tar.gz /tmp/ceph.tar.gz

    # Copy ceph configs to all nodes except master
    exclude_master=("${hosts[@]:1}")
    for h in "${exclude_master[@]}"; do
        ${scpcmd[@]} /tmp/ceph.tar.gz $baseuser@$h:ceph.tar.gz
        ${sshcmd[@]} $baseuser@$h "sudo tar xPfz ceph.tar.gz -C /"
        echo -e "Copy /etc/ceph to $h"
    done

    # # Add monitors without master
    exclude_master=("${monitors[@]:1}")
    for h in "${exclude_master[@]}"; do
        echo "Add $h to cluster as monitor"
        ${sshcmd[@]} $baseuser@$h \
            NETWORK_CIDR="$network_cidr" \
            MON_IP="$h" \
            'bash -s' < $scripts_path/ceph/mon.sh
    done
fi


if $MANAGERS ; then
    echo "[[ CEPH MANAGERS ]]"
    # Add managers
    for h in "${managers[@]}"; do
        echo "Add $h to cluster as manager"
        ${sshcmd[@]} $baseuser@$h < $scripts_path/ceph/mgr.sh
    done
fi

if $OSD ; then
    echo "[[ CEPH OSD ]]"
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
        ${sshcmd[@]} $baseuser@$h \
            PART_SIZE="$part_size" \
            'bash -s' < $scripts_path/ceph/osd.sh
        echo "Start OSD on $h"
    done
fi

if $MDS ; then
    echo "[[ CEPH MDS ]]"
    # Start ceph MDS on all nodes
    for h in "${hosts[@]}"; do
        ${sshcmd[@]} $baseuser@$h \
            METADATA_POOL_PG=256 \
            DATA_POOL_PG=512 \
            'bash -s' < $scripts_path/ceph/mds.sh
        echo "Start MDS on $h"
    done
fi

if $CONFIGURE ; then
    echo "[[ CEPH configure ]]"
    # Configure ceph pool
    ${sshcmd[@]} $baseuser@$master "docker exec \
        ceph-mon ceph osd pool set cephfs_data size 2"
    # ${sshcmd[@]} $baseuser@$master "docker exec \
    #     ceph-mon ceph osd pool set cephfs_metadata size 2"
    ${sshcmd[@]} $baseuser@$master "docker exec \
        ceph-mon ceph osd set nodeep-scrub"

    # Generate token volume token
    token=$(\
        ${sshcmd[@]} $baseuser@$master "docker exec ceph-mon \
ceph auth get-or-create client.dockerswarm osd 'allow rw' mon 'allow r' mds 'allow' \
| grep 'key' | sed -e 's#\tkey \= ##g'")
    echo "Generate new token for all nodes: $token"

    # Configure disks
    manager_ips=$(echo -n "${managers[@]}" | sed -e 's# #,#g')
    for h in "${hosts[@]}"; do
        echo "Configure disk on $h"
        ${sshcmd[@]} $baseuser@$h "sudo su -c \
    'echo -e \"$manager_ips:6789:/\t/data/\tceph\tname=dockerswarm,\
secret=$token,noatime,_netdev 0 2\" > /etc/fstab'"
        echo "Push disk config to fstab"
        ${sshcmd[@]} $baseuser@$h "sudo mkdir -p /data"
        echo "Mounting ceph partition ..."
        ${sshcmd[@]} $baseuser@$h "sudo mount -a"
    done
fi

exit 0
