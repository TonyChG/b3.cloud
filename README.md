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

[![asciicast](https://asciinema.dotfile.eu/a/C2kWt93gReOxNesOLY2zwPqJ6.png)](https://asciinema.dotfile.eu/a/C2kWt93gReOxNesOLY2zwPqJ6)

## TODO

- Drain au niveau du manager
