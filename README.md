# TP1 - Cloud
> Formateur: Léo GODEFROY\
> Groupe: Antoine CHINY - Benjamin GIRALT

## Network used
| Machine/Hostname | Address   | Host Machine Used  |
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

*Note : All of the machines use /24 as the subnet mask*

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

Clone vagrant coreos repository in the project
```
git clone https://github.com/TonyChG/b3.cloud
cd b3.cloud
git clone https://github.com/coreos/coreos-vagrant.git
```


Push keepalived and ceph/daemon images to all nodes on provisioning
```
# on your host
cd b3.cloud
docker pull ceph/daemon
docker pull osixia/keepalived:1.3.5
docker save ceph/daemon -o data/images/ceph_daemon.tar.gz
docker save osixia/keepalived:1.3.5 -o data/images/keepalived.tar.gz
# You can save all images you want in data/images
# They will be automatically sync to all node on vagrant provisioning
# Usefull: on low internet conection
```

## Usage

Configure the Vagrantfile
```
vim Vagrantfile
# >>> Vagrantfile
# 123       ip = "192.168.4.#{i+100}"
# 124       # config.vm.network "public_network", ip: ip, bridge: "enp1s31f6"
# 125       config.vm.network "private_network", ip: ip
# 126       # This tells Ignition what the IP for eth1 (the host-only adapter) should be
# 127       config.ignition.ip = ip
```

Start the test infra
```
# Starting vagrant machines
cd coreos-vagrant
vagrant up

# Test conection
telnet 192.168.4.101 22
```

### To deploy ceph cluster
```
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
```

[![asciicast](https://asciinema.org/a/212494.svg)](https://asciinema.org/a/212494?autoplay=1)

### To deploy the swarm
```
bash scripts/swarminit.sh
```

[![asciicast](https://asciinema.org/a/212495.svg)](https://asciinema.org/a/212495?autoplay=1)

### Ajouter un node ceph
```
bash scripts/add_node.sh --ip=<node ip> --keyring
bash scripts/add_node.sh --ip=<node ip> --osd
bash scripts/add_node.sh --ip=<node ip> --mds
bash scripts/add_node.sh --ip=<node ip> --configure
```

[![asciicast](https://asciinema.org/a/212496.svg)](https://asciinema.org/a/212496?autoplay=1)

```
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

### Déployer un service sur le swarm
(En reprenant l'exemple de swarmprom)\
Déployer une stack sur le swarm
```
docker stack deploy -c docker-compose.yml <nom stack>
```

Permettre le monitoring du service
```
Utiliser le mode expérimental de Docker (config du daemon)
```

Assurer la HA 
```
dans le docker compose : 
mode: replicated
replicas: <nombre de répliques>
```
Assurer le HTTPS
```
mettre les labels dans traefik:
```

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
`--cap-add=NET_ADMIN'` : donne un accès au contrôle de la couche réseau de l'hôte, gérée par le kernel 

```
core@core-201 ~ $ docker ps

CONTAINER ID        IMAGE                     COMMAND                 CREATED             STATUS              PORTS               NAMES
529a7d1a93e1        osixia/keepalived:1.3.5   "/container/tool/run"   24 minutes ago      Up 20 seconds                           keepalived

core@core-201 ~ $ docker inspect 5 | grep -i pid
            "Pid": 1093,
            "PidMode": "",
            "PidsLimit": 0,
           
core@core-201 ~ $ sudo nsenter -t 1093 -n /bin/sh

sh-4.3# ip a | grep inet
    inet 127.0.0.1/8 scope host lo
    inet6 ::1/128 scope host
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic eth0
    inet 192.168.4.100/32 scope global eth0
    inet6 fe80::a00:27ff:fe24:4334/64 scope link
    inet 192.168.4.201/24 brd 192.168.4.255 scope global eth1
    inet6 fe80::a00:27ff:fed7:28a9/64 scope link
    inet 172.18.0.1/16 brd 172.18.255.255 scope global docker_gwbridge
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
```
On retrouve bien l'adresse réseau de notre hôte, ici présente dans le conteneur. Keepalived en a besoin pour pouvoir utiliser dynamiquement cette adresse comme une des passerelles par défaut reliée à l'IP virtuelle

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
*Note : certains screenshots ont été pris quand le cluster de 10 machines était opérationnel, d'autres quand il y avait seulement 5 machines : d'où la différence de certaines données.*

### Grafana
![grafana docker nodes](https://github.com/TonyChG/b3.cloud/blob/dev/resources/graffana_docker_nodes.png)
![grafana prometheus](https://github.com/TonyChG/b3.cloud/blob/dev/resources/graffana_prometheus.png)
![grafana swarm 1](https://github.com/TonyChG/b3.cloud/blob/dev/resources/graffana_swarm1.png)
![grafana swarm 2](https://github.com/TonyChG/b3.cloud/blob/dev/resources/graffana_swarm2.png)
![grafana swarm 3](https://github.com/TonyChG/b3.cloud/blob/dev/resources/graffana_swarm3.png)
![grafana swarm 4](https://github.com/TonyChG/b3.cloud/blob/dev/resources/graffana_swarm4.png)

### Traefik
![traefik](https://github.com/TonyChG/b3.cloud/blob/dev/resources/traeffik.png)

### Weave
![weave containers](https://github.com/TonyChG/b3.cloud/blob/dev/resources/weave_containers.png)
![weave nodes](https://github.com/TonyChG/b3.cloud/blob/dev/resources/weave_nodes.png)
![weave services](https://github.com/TonyChG/b3.cloud/blob/dev/resources/weave_services.png)
![weave hosts](https://github.com/TonyChG/b3.cloud/blob/dev/resources/weaves_hosts.png)

