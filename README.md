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
# Starting vagrant machines
cd coreos-vagrant
vagrant up

# To deploy swarm
bash scripts/swarminit.sh

# To deploy ceph
vim scripts/ceph-config
# After editing source the ceph config
source scripts/ceph-config
bash scripts/ceph.sh --help

# Start with the ceph images
bash scripts/ceph.sh --pull-images

# Deploy ceph monitors
bash scripts/ceph.sh --monitors

# Deploy ceph managers
bash scripts/ceph.sh --managers

# Run ceph osd on all nodes
bash scripts/ceph.sh --osd

# Run ceph mds on all nodes
bash scripts/ceph.sh --mds

# Copy repository to core nodes
ssh-add $HOME/.vagrant.d/insecure_private_key
scp -q -o "StrictHostKeyChecking=no" data.tar.gz core@$MASTER:
ssh -q -o "StrictHostKeyChecking=no" core@$MASTER "sudo tar xvfPz data.tar.gz -C /"
```

## TODO

- Drain au niveau du manager
