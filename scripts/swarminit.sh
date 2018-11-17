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
vagrant_ssh_key="$HOME/.vagrant.d/insecure_private_key"

master_manager="192.168.4.101"
other_managers=( \
'192.168.4.102'  \
# '192.168.4.201'  \
# '192.168.4.202'  \
# '192.168.4.203'  \
)
workers=(       \
'192.168.4.103'  \
'192.168.4.104' \
'192.168.4.105' \
# '192.168.4.204' \
# '192.168.4.205' \
)

sshcmd=(ssh -q -o "StrictHostKeyChecking=no" -i $vagrant_ssh_key)

${sshcmd[@]} $baseuser@$master_manager "docker swarm leave --force"
>/dev/null ${sshcmd[@]} $baseuser@$master_manager "docker swarm init --advertise-addr $master_manager"
token_manager="$(${sshcmd[@]} $baseuser@$master_manager "docker swarm join-token manager" | egrep token | awk '{print$5}')"
token_worker="$(${sshcmd[@]} $baseuser@$master_manager "docker swarm join-token worker" | egrep token | awk '{print$5}')"

echo "Manager Token : $token_manager"
echo "Worker Token  : $token_worker"

for m in ${other_managers[@]}; do
    ${sshcmd[@]} $baseuser@$m "docker swarm leave --force"
    ${sshcmd[@]} $baseuser@$m "docker swarm join --token $token_manager $master_manager:2377"
done

for w in ${workers[@]}; do
    ${sshcmd[@]} $baseuser@$w "docker swarm leave --force"
    ${sshcmd[@]} $baseuser@$w "docker swarm join --token $token_worker $master_manager:2377"
done
