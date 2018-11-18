#!/bin/bash
# =============================================================================
# Name     : add_node.sh
# Function :
# Usage    :
# Version  : 1.0.0
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# When        Who      What
# 11/18/18    tonychg
# =============================================================================

ssh_privkey="$HOME/.vagrant.d/insecure_private_key"
# Wrap ssh commands
sshcmd=(ssh -q -i $ssh_privkey -o "StrictHostKeyChecking=no")
scpcmd=(scp -q -i $ssh_privkey -o "StrictHostKeyChecking=no")

scripts_path="`dirname $(realpath $0)`"
source $scripts_path/hosts

_DEPLOY_OSD=false
_DEPLOY_MDS=false
_CONFIGURE=false
_COPY_KEYRING=false

function usage {
echo -e "\
 Usage     : ./add_node.sh

             --ip=addr      New Node IP
             --keyring      Copy ceph keyring
             --mds          Start mds ceph/daemon
             --osd          Start osd ceph/daemon
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
        --ip)
            _NODE_IP=$VALUE       ;;
        --mds)
            _DEPLOY_MDS=true      ;;
        --configure)
            _CONFIGURE=true       ;;
        --keyring)
            _COPY_KEYRING=true    ;;
        --osd)
            _DEPLOY_OSD=true      ;;
        *)
            >&2 usage
            >&2 echo "Unknow options: %s" $LABEL
            exit 1
            ;;
    esac
    shift
done

if [[ -z $_NODE_IP ]]; then
    usage
    >&2 echo -e "Invalid ip address $_NODE_IP"
    exit 1
fi

if $_COPY_KEYRING ; then
    # Copy keyring
    ${scpcmd[@]} /tmp/ceph.tar.gz $BASEUSER@$_NODE_IP:ceph.tar.gz
    if [[ $? -ne 0 ]]; then
        >&2 echo "FATAL: Cannot connect to $_NODE_IP"
        exit 1
    fi
    ${sshcmd[@]} $BASEUSER@$_NODE_IP "sudo tar xPfz ceph.tar.gz -C /"
    echo -e "Copy /etc/ceph to $_NODE_IP"
fi

if $_DEPLOY_OSD ; then
    # OSD
    ${scpcmd[@]} /tmp/ceph.keyring $BASEUSER@$_NODE_IP:ceph.keyring
    ${sshcmd[@]} $BASEUSER@$_NODE_IP "\
        sudo mkdir -p /var/lib/ceph/bootstrap-osd && \
        sudo mv -v ceph.keyring /var/lib/ceph/bootstrap-osd/ceph.keyring"
    echo "Copy ceph.keyring to $_NODE_IP"
    ${sshcmd[@]} $BASEUSER@$_NODE_IP \
        PART_SIZE="$PART_SIZE" \
        'bash -s' < $scripts_path/ceph/osd.sh
    echo "Start OSD on $_NODE_IP"
fi

if $_DEPLOY_MDS ; then
    # MDS
    ${sshcmd[@]} $BASEUSER@$_NODE_IP \
        DATA_POOL_PG=$DATA_POOL_PG \
        METADATA_POOL_PG=$METATA_POOL_PG \
        'bash -s' < $scripts_path/ceph/mds.sh
    echo "Start MDS on $_NODE_IP"
fi

if $_CONFIGURE ; then
    # Generate token volume token
    token=$(\
        ${sshcmd[@]} $BASEUSER@$MASTER "docker exec ceph-mon \
ceph auth get-or-create client.dockerswarm osd 'allow rw' mon 'allow r' mds 'allow' \
| grep 'key' | sed -e 's#\tkey \= ##g'")
    echo "Generate new token for all nodes: $token"

    # Configure disks
    manager_ips=$(echo -n "${MANAGERS[@]}" | sed -e 's# #,#g')
    echo "Configure disk on $_NODE_IP"
    ${sshcmd[@]} $BASEUSER@$_NODE_IP "sudo su -c \
'echo -e \"$manager_ips:6789:/\t/data/\tceph\tname=dockerswarm,\
secret=$token,noatime,_netdev 0 2\" > /etc/fstab'"
    echo "Push disk config to fstab"
    ${sshcmd[@]} $BASEUSER@$_NODE_IP "sudo mkdir -p /data"
    echo "Mounting ceph partition ..."
    ${sshcmd[@]} $BASEUSER@$_NODE_IP "sudo mount -a"
fi
