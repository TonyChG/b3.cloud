#!/bin/bash
# =============================================================================
# Name     : deploy.sh
# Function :
# Usage    :
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# Date        Who      What
# 11/02/18    tonychg
# =============================================================================

baseuser="core"
master_manager="192.168.4.101"
other_managers=( \
'192.168.4.102'  \
'192.168.4.201'  \
'192.168.4.202'  \
)
workers=(       \
'192.168.4.103' \
'192.168.4.104' \
'192.168.4.105' \
'192.168.4.203' \
'192.168.4.204' \
'192.168.4.205' \
)
# ssh -i $HOME/.vagrant.d/insecure_private_key $baseuser@$master_manager "docker swarm init --advertise-addr master_manager"
token_manager="$(ssh -o "StrictHostKeyChecking=false" -i $HOME/.vagrant.d/insecure_private_key $baseuser@$master_manager "docker swarm join-token manager" | egrep token | awk '{print$5}')"
token_worker="$(ssh -o "StrictHostKeyChecking=false" -i $HOME/.vagrant.d/insecure_private_key $baseuser@$master_manager "docker swarm join-token worker" | egrep token | awk '{print$5}')"

echo "Manager Token : $token_manager"
echo "Worker Token  : $token_worker"

for m in ${other_managers[@]}; do
    ssh -o "StrictHostKeyChecking=false" -i $HOME/.vagrant.d/insecure_private_key $baseuser@$m "docker swarm join --token $token_manager $master_manager:2377"
done

for w in ${workers[@]}; do
    ssh -o "StrictHostKeyChecking=false" -i $HOME/.vagrant.d/insecure_private_key $baseuser@$w "docker swarm join --token $token_worker $master_manager:2377"
done
