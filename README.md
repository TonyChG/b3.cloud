# TP1 - Cloud
> Formateur: Léo GODEFROY
> Groupe: Antoine CHINY - Benjamin GIRALT

## Requirements
- `git`
- `vagrant`
- `vagrant-ignition`

* To install vagrant-ignition
```
git clone https://github.com/coreos/vagrant-ignition
gem build vagrant-ignition.gemspec
vagrant plugin install vagrant-ignition-0.0.3.gem
```

* Create the coreos base box with required images
```
# Clone this repo
cd b3.cloud
git clone https://github.com/coreos/coreos-vagrant
cp Vagrantfile coreos-vagrant/Vagrantfile

# Update the network configuration
# Second disk size
vim coreos-vagrant/Vagrantfile
```

## Usage

```
vim Vagrantfile
# >>> Vagrantfile
# 123       ip = "192.168.4.#{i+100}"
# 124       # config.vm.network "public_network", ip: ip, bridge: "enp1s31f6"
# 125       config.vm.network "private_network", ip: ip
# 126       # This tells Ignition what the IP for eth1 (the host-only adapter) should be
# 127       config.ignition.ip = ip

# Starting vagrant machines
cd coreos-vagrant
vagrant up

# To deploy ceph cluster
vim scripts/hosts
# After editing the ceph config file
# Map ceph entities to the Vagrant provisioned machines
source scripts/hosts
bash scripts/ceph.sh --help

# Start with the ceph images
bash scripts/ceph.sh --pull-images

# Start ceph monitors
bash scripts/ceph.sh --monitors

# Start ceph managers
bash scripts/ceph.sh --managers

# Start ceph osd on all nodes
bash scripts/ceph.sh --osd

# Start ceph mds on all nodes
bash scripts/ceph.sh --mds

# Mount ceph partition
bash scripts/ceph.sh --configure

# To deploy swarm
bash scripts/swarminit.sh

# Copy repository to core nodes
cd b3.cloud
ssh-add $HOME/.vagrant.d/insecure_private_key
tar cvfPz data.tar.gz data
source scripts/hosts
scp -q -o "StrictHostKeyChecking=no" data.tar.gz core@$MASTER:
ssh -q -o "StrictHostKeyChecking=no" core@$MASTER "sudo tar xvfPz data.tar.gz -C /"

vagrant ssh [master]
docker network create backend -d overlay
docker stack deploy -c /data/app-repo/traefik/docker-compose.yml traefik
docker stack deploy -c /data/app-repo/registry/docker-compose.yml registry
```

[![demo](https://asciinema.dotfile.eu/a/21?autoplay=1)](https://asciinema.dotfile.eu/a/21?autoplay=1)

## TODO

- Drain au niveau du manager


## Docker registry
https://docs.docker.com/engine/swarm/stack-deploy/#set-up-a-docker-registry

# Create the registry
docker service create --name registry --publish published=5000,target=5000 registry:2 


## Swarmprom


## Q1
bind du socket docker
`-v /var/run/docker.sock:/var/run/docker.sock`

## Q2
Un DFS est un système de fichiers distribués permettant de :
*  fournir une arborescence logique aux données partagées depuis des emplacements différents
* rassembler différents partages de fichiers à un endroit unique de façon transparente
* d’assurer la redondance et la disponibilité des données grâce à la réplication

## Q3
Pour notre solution d'automatisation de déploiement CEPH : cf `/scripts/ceph.sh`

## Q4
1 conteneur lancé sur l'hôte core-103
```
core@core-201 ~ $ docker service ps registry
ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
o0vcw3ytpkgv        registry.1          registry:2          core-103            Running             Running 36 seconds ago      
```

## Q5
L'argument `--publish` permet de publier des ports de services pour les rendre accessibles à tous les hôtes du swarm

## Q6
Permet d'utiliser la stack network du Docker host

