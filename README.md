# TP1 - Cloud
> Formateur: Léo GODEFROY
> Groupe: Antoine CHINY - Benjamin GIRALT

## Network used
*All of the machines use /24 as the subnet mask*
| Machine/Hostname | Address   | Machine Used  |
| ------------- |:-------------:| -----:|
| Antoine Host | 192.168.4.2  | Antoine |
| Benjamin Host | 192.168.4.3  | Benjamin |
| core-101 | 192.168.4.101  | Antoine |
| core-102 | 192.168.4.102  | Antoine |
| core-103 | 192.168.4.103  | Antoine |
| core-104 | 192.168.4.104  | Antoine |
| core-105 | 192.168.4.105  | Antoine |
| core-201 | 192.168.4.201  | Benjamin |
| core-202 | 192.168.4.202  | Benjamin |
| core-203 | 192.168.4.203  | Benjamin |
| core-204 | 192.168.4.204  | Benjamin |
| core-205 | 192.168.4.205  | Benjamin |


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

# Questions
### Question 1
bind du socket docker
`-v /var/run/docker.sock:/var/run/docker.sock`

### Question 2
Un DFS est un système de fichiers distribués permettant de :
*  fournir une arborescence logique aux données partagées depuis des emplacements différents
* rassembler différents partages de fichiers à un endroit unique de façon transparente
* d’assurer la redondance et la disponibilité des données grâce à la réplication

### Question 3
Pour notre solution d'automatisation de déploiement CEPH : cf `/scripts/ceph.sh`

### Question 4
1 conteneur lancé sur l'hôte core-103
```
core@core-201 ~ $ docker service ps registry
ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
o0vcw3ytpkgv        registry.1          registry:2          core-103            Running             Running 36 seconds ago      
```

### Question 5
L'argument `--publish` permet de publier des ports de services pour les rendre accessibles à tous les hôtes du swarm

### Question 6
Permet d'utiliser la stack network du Docker host
`--cap-add=NET_ADMIN' : donne un accès au contrôle de la couche réseau de l'hôte, gérée par le kernel 

### Question 7
**Principe de priorité de Keepalived**: Cette priorité est le paramètre qui va permettre le choix d'un routeur master pour le groupe VRRP. Le routeur du groupe ayant la priorité la plus haute est choisi comme master. En cas d'égalité, le routeur ayant l'adresse IP la plus élevée est choisi.  
Le **VRRP (Virtual Router Redundancy Procol)** permet de fournir une adresse virtuelle comme passerelle par défaut pour tous les hôtes d'un même réseau. Cette adresse IP virtuelle aura pour but d'augmenter la disponibilité de la passerelle par défaut des hôtes d'un même réseau, en redirigeant dynamiquement (et de façon transparente pour l'utilisateur) vers une des adresses définie dans le pool.

### Question 8
Un collector est une application qui tourne sur un serveur dans une infrastructure et qui utilise des protocoles standards de monitoring pour monitorer intelligemment des machines au sein d'une infrastructure.

### Question 9
* **prometheus**: système open source de monitoring et d'alerting. Principales fonctionnalités : dashboarding de plusieurs nodes, requêtes HTTP de time serie collection, single serveurs autonomes, data model multi-dimensionnel avec données de time serie identifiées par leur nom et paires clefs/valeurs

* **grafana**: visualisation et mise en forme de données métriques 

* **node-exporter**: Prometheus exporter pour hardware et métriques OS exposées par les kernels Unix  

* **cadvisor**: analyseur de ressources d'usages et de performances de conteneurs 

* **dockerd-exporter**: exporteur de metrics du Docker Daemon vers Prometheus 

* **alertmanager**: gère les alertes envoyées par les applications, comme le serveur Prometheus. S'occupe de dédupliquer, grouper et router les alertes vers un système d'email ou de messagerie 

* **unsee**: dashboard d'alerte pour Prometheur AlertManager

* **caddy**: reverse proxy et authentification pour Prometheus, alertmanager and unsee

### Question 10
**Fonctionnement de traefik :**\
Reverse proxy bind sur le Docker socket, qui lit des labels sur les conteneurs qui se lancent pour savoir si ces derniers seront placés en backend ou frontend, permet égaelement de router dynamiquement, de load balancer le swarm dynamiquement.

### Question 11
**Pour les configurations, les outils de déploiements et les applications elles-mêmes** : seront versionnés avec des dépôts Git. Ces dépôts pourront être soumis à des pipelines de déploiement continu, qui synchronizeront ces dépôts en fonction de tags et qui les déploieront sur des serveurs mirror.

**Pour les données**: elles seront sauvegardées sur des serveur des serveurs de backup, proposant un service type Borg, accessible depuis SSH


# Metrics
