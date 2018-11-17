#!/bin/bash
# =============================================================================
# Name     : ceph.sh
# Function : Deploy on ceph on swarm cluster using ssh and docker
# Usage    : ./ceph.sh
#            --remove       Remove ceph cluster
#            --all          Deploy all ceph nodes
#            --managers     Deploy the ceph master and managers
#            --monitors     Deploy ceph monitors
#            --osd          Deploy ceph osd
#            --mds          Deploy ceph mds
#            --pull-images  Download require images default: ceph/daemon
#            --configure  Configure ceph cluster
# Example  : HOSTS=(192.168.4.100) MANAGERS=(192.168.4.100) MONITORS=(192.168.4.100) 
#            bash scripts/ceph.sh
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# Date        Who      What
# 11/04/18    tonychg  Created
# 11/07/18    tonychg  Ceph roles refactorisation + Params for each ones
#                      Environement variables for roles assignment
# =============================================================================

# Params
_REMOVE=false
_DEPLOY_MONITORS=false
_DEPLOY_MANAGERS=false
_DEPLOY_OSD=false
_DEPLOY_MDS=false
_CONFIGURE=false
_PULL_IMAGES=false


# Fatal exit with error message
function fatal {
    if [[ $? -ne 0 ]]; then
        >&2 echo -e "$1"
        exit -1
    fi
}

ssh_privkey="$HOME/.vagrant.d/insecure_private_key"
# Wrap ssh commands
sshcmd=(ssh -q -i $ssh_privkey -o "StrictHostKeyChecking=no")
scpcmd=(scp -q -i $ssh_privkey -o "StrictHostKeyChecking=no")

scripts_path="`dirname $(realpath $0)`"
source $scripts_path/hosts

function usage {
echo -e "\
###############################################################################
#                             Deploy CEPH cluster                             #
###############################################################################

 ENV       : HOSTS     All ceph nodes              (ip|hostname)
             MONITORS  Ceph monitors nodes         (ip|hostname)
             MANAGERS  Ceph managers nodes         (ip|hostname)
             More configs in hosts file
             > vim scripts/ceph.sh

 Usage     : source hosts
             ./ceph.sh

             --remove|-r    Remove cluster
             --all          Deploy all ceph nodes
             --pull-images  Download require images
                            default: ceph/daemon
             --monitors     Deploy the ceph master and monitors
             --managers     Deploy ceph managers
             --osd          Deploy ceph osd
             --mds          Deploy ceph mds
             --configure    Configure ceph cluster 
                            (To run after roles deployment)
"
}

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

while ! [[ -z $1 ]]; do
    LABEL=$(echo $1 | awk -F= '{print $1}')
    VALUE=$(echo $1 | awk -F= '{print $2}')
    case $LABEL in
        --help|-h)
            usage && exit 0       ;;
        --remove|-r)
            _REMOVE=true          ;;
        --configure)
            _CONFIGURE=true       ;;
        --monitors)
            _DEPLOY_MONITORS=true ;;
        --managers)
            _DEPLOY_MANAGERS=true ;;
        --mds)
            _DEPLOY_MDS=true      ;;
        --osd)
            _DEPLOY_OSD=true      ;;
        --pull-images)
            _PULL_IMAGES=true     ;;
        --all)
            _DEPLOY_MONITORS=true
            _DEPLOY_MANAGERS=true
            _DEPLOY_MDS=true
            _DEPLOY_OSD=true
            ;;
        *)
            >&2 usage
            >&2 echo "Unknow options: %s" $LABEL
            exit 1
            ;;
    esac
    shift
done

# Revert all operations
if $_REMOVE ; then
    echo "[[ REMOVING CEPH CLUSTER ]]"
    for h in ${HOSTS[@]}; do
        shared_disk=$(${sshcmd[@]} $BASEUSER@$h "lsblk | egrep $PART_SIZE\"G\" | awk '{print\$1}'")
        ${sshcmd[@]} $BASEUSER@$h "sudo sgdisk -Z /dev/$shared_disk"
        ${sshcmd[@]} $BASEUSER@$h "sudo sgdisk -g /dev/$shared_disk"
        ${sshcmd[@]} $BASEUSER@$h "sudo partprobe /dev/$shared_disk"
        ${sshcmd[@]} $BASEUSER@$h "\
            ! [[ -z \$(docker ps -aq) ]] && docker rm -f \$(docker ps -aq)"
        ${sshcmd[@]} $BASEUSER@$h "\
            sudo rm -rfv ceph.tar.gz /var/lib/ceph /etc/ceph /etc/fstab"
        ${sshcmd[@]} $BASEUSER@$h "sudo systemctl reboot -i"
    done
    exit 0
fi

if $_PULL_IMAGES ; then
    for h in ${HOSTS[@]}; do
        echo "Pull image $CEPH_IMAGE on $h              "
        ${sshcmd[@]} $BASEUSER@$h "docker pull $CEPH_IMAGE"
        if [[ $? -ne 0 ]]; then
            >&2 echo -e "\n ERROR Cannot download $CEPH_IMAGE"
        else
            echo "OK"
        fi
    done
fi

# Start ceph master
if $_DEPLOY_MONITORS ; then
    echo "[[ DEPLOYING CEPH MONITORS ]]"
    # Start ceph master
    ${sshcmd[@]} $BASEUSER@$MASTER \
        NETWORK_CIDR=$NETWORK_CIDR \
        MON_IP=$MASTER \
        "bash -s" < $scripts_path/ceph/mon.sh
    fatal "Fail to init ceph root manager"

    # Wait starting of the ceph master
    echo "Waiting start of the master ..." ; sleep 1
    >/dev/null 2>&1 ${sshcmd[@]} $BASEUSER@$MASTER "docker exec ceph-mon ceph status"
    [[ $? -ne 0 ]] && fatal "Cannot start master: docker logs ceph-mon"

    # Get ceph config from master
    ${sshcmd[@]} $BASEUSER@$MASTER "sudo tar cPfz ceph.tar.gz /etc/ceph"
    ${scpcmd[@]} $BASEUSER@$MASTER:ceph.tar.gz /tmp/ceph.tar.gz

    # Copy ceph configs to all nodes except master
    exclude_master=("${HOSTS[@]:1}")
    for h in "${exclude_master[@]}"; do
        ${scpcmd[@]} /tmp/ceph.tar.gz $BASEUSER@$h:ceph.tar.gz
        ${sshcmd[@]} $BASEUSER@$h "sudo tar xPfz ceph.tar.gz -C /"
        echo -e "Copy /etc/ceph to $h"
    done

    # # Add monitors without master
    exclude_master=("${MONITORS[@]:1}")
    for h in "${exclude_master[@]}"; do
        echo "Add $h to cluster as monitor"
        ${sshcmd[@]} $BASEUSER@$h \
            NETWORK_CIDR="$NETWORK_CIDR" \
            MON_IP="$h" \
            'bash -s' < $scripts_path/ceph/mon.sh
    done
fi


if $_DEPLOY_MANAGERS ; then
    echo "[[ DEPLOYING CEPH MANAGERS ]]"
    # Add managers
    for h in "${MANAGERS[@]}"; do
        echo "Add $h to cluster as manager"
        ${sshcmd[@]} $BASEUSER@$h < $scripts_path/ceph/mgr.sh
    done
fi

if $_DEPLOY_OSD ; then
    echo "[[ DEPLOYING CEPH OSD ]]"
    # Get ceph keyring
    ${sshcmd[@]} $BASEUSER@$MASTER "\
    docker exec ceph-mon ceph auth get client.bootstrap-osd" > /tmp/ceph.keyring

    # Start ceph OSD on all nodes
    for h in "${HOSTS[@]}"; do
        ${scpcmd[@]} /tmp/ceph.keyring $BASEUSER@$h:ceph.keyring
        ${sshcmd[@]} $BASEUSER@$h "\
            sudo mkdir -p /var/lib/ceph/bootstrap-osd && \
            sudo mv -v ceph.keyring /var/lib/ceph/bootstrap-osd/ceph.keyring"
        echo "Copy ceph.keyring to $h"
        ${sshcmd[@]} $BASEUSER@$h \
            PART_SIZE="$PART_SIZE" \
            'bash -s' < $scripts_path/ceph/osd.sh
        echo "Start OSD on $h"
    done
fi

if $_DEPLOY_MDS ; then
    echo "[[ DEPLOYING CEPH MDS ]]"
    # Start ceph MDS on all nodes
    for h in "${HOSTS[@]}"; do
        ${sshcmd[@]} $BASEUSER@$h \
            DATA_POOL_PG=$DATA_POOL_PG \
            METADATA_POOL_PG=$METATA_POOL_PG \
            'bash -s' < $scripts_path/ceph/mds.sh
        echo "Start MDS on $h"
    done
fi

if $_CONFIGURE ; then
    echo "[[ CEPH configure ]]"
    # Configure ceph pool
    ${sshcmd[@]} $BASEUSER@$MASTER "docker exec \
        ceph-mon ceph osd pool set cephfs_data size 2"
    # ${sshcmd[@]} $BASEUSER@$MASTER "docker exec \
    #     ceph-mon ceph osd pool set cephfs_metadata size 2"
    ${sshcmd[@]} $BASEUSER@$MASTER "docker exec \
        ceph-mon ceph osd set nodeep-scrub"

    # Generate token volume token
    token=$(\
        ${sshcmd[@]} $BASEUSER@$MASTER "docker exec ceph-mon \
ceph auth get-or-create client.dockerswarm osd 'allow rw' mon 'allow r' mds 'allow' \
| grep 'key' | sed -e 's#\tkey \= ##g'")
    echo "Generate new token for all nodes: $token"

    # Configure disks
    manager_ips=$(echo -n "${MANAGERS[@]}" | sed -e 's# #,#g')
    for h in "${HOSTS[@]}"; do
        echo "Configure disk on $h"
        ${sshcmd[@]} $BASEUSER@$h "sudo su -c \
    'echo -e \"$manager_ips:6789:/\t/data/\tceph\tname=dockerswarm,\
secret=$token,noatime,_netdev 0 2\" > /etc/fstab'"
        echo "Push disk config to fstab"
        ${sshcmd[@]} $BASEUSER@$h "sudo mkdir -p /data"
        echo "Mounting ceph partition ..."
        ${sshcmd[@]} $BASEUSER@$h "sudo mount -a"
    done
fi

exit 0
