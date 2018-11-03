#!/bin/bash
# =============================================================================
# Name     : create_data_volume.sh
# Function : Create a /data volume with lvm
# Usage    : ./create_data_volume.sh
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# Date        Who      What
# 11/03/18    tonychg  Created
# =============================================================================

vg_name="data"
lv_name="root"
target_device=$(/usr/sbin/fdisk -l | grep '10 GiB' | awk -F: '{print $1}' | sed -e 's#Disk ##g')

if [[ -z $target_device ]]; then
    >&2 echo -e "Target device is required
Example: $0 /dev/sda"
    exit 1
fi

systemctl enable lvm2-lvmetad.service
systemctl enable lvm2-lvmetad.socket
systemctl start lvm2-lvmetad.service
systemctl start lvm2-lvmetad.socket
systemctl stop docker

mkdir -p /$vg_name
/usr/sbin/pvcreate $target_device
/usr/sbin/vgcreate $vg_name $target_device
/usr/sbin/lvcreate -l 100%FREE -n $lv_name $vg_name
>/dev/null /usr/sbin/mkfs.ext4 "/dev/mapper/$vg_name-$lv_name"

mount "/dev/mapper/$vg_name-$lv_name" "/$vg_name"

rm -rf /data/*
chown -R core:core /data

systemctl enable docker
systemctl start docker
