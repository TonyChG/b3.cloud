#!/bin/bash
# =============================================================================
# Name     : build_coreos_base.sh
# Function : Create a core os base box with all needed images and disk config
#            Only supported provider: virtualbox
# Usage    : ./build_coreos_base.sh
# vi       : set expandtab shiftwidth=4 softtabstop=4
# =============================================================================
# Date        Who      What
# 11/02/18    tonychg  Created
# =============================================================================

box_name="coreos-base"
target="$HOME/.vagrant.d/boxes/$box_name"
docker_images=(           \
"ceph/daemon"             \
"osixia/keepalived:1.3.5" \
"traefik:latest"          \
)

if [[ -d $target ]]; then
    >&2 echo -e "\
[FATAL] Vagrant Box $box_name already exists Remove it with :
# vagrant box remove -f $box_name"
    exit 1
fi
# Clone base coreos-vagrant repo
rm -rf /tmp/coreos-vagrant
git clone https://github.com/coreos/coreos-vagrant /tmp/coreos-vagrant
cd /tmp/coreos-vagrant

# Create default coreos node
/usr/bin/vagrant up
[[ $? -ne 0 ]] && >&2 echo -e "[FATAL] Delete all the previous created core-01 vms" && exit 1

# Pull all required docker images
for i in ${docker_images[@]}; do
    echo -e "Fetching $i ..."
    >/dev/null /usr/bin/vagrant ssh -c "docker pull $i"
done

# Add this box to vagrant boxes list
mkdir -p $target
/usr/bin/vagrant package --output $target/base.box
/usr/bin/vagrant box add -f $box_name $target/base.box
/usr/bin/vagrant destroy -f

# Copy requied ruby scripts
cd $target/0/virtualbox
cp -v $HOME/.vagrant.d/boxes/coreos-alpha/1939.0.0/virtualbox/base_mac.rb .
cp -v $HOME/.vagrant.d/boxes/coreos-alpha/1939.0.0/virtualbox/change_host_name.rb .
cp -v $HOME/.vagrant.d/boxes/coreos-alpha/1939.0.0/virtualbox/configure_networks.rb .
cp -v $HOME/.vagrant.d/boxes/coreos-alpha/1939.0.0/virtualbox/Vagrantfile .
rm -rf /tmp/coreos-vagrant

# Add a Vagrantfile template
mkdir -p $HOME/.vagrant.d/templates
cat > $HOME/.vagrant.d/templates/Vagrantfile-coreos.erb <<EOF
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.require_version ">= 1.6.0"

# Make sure the vagrant-ignition plugin is installed
required_plugins = %w(vagrant-ignition)

\$core_num_instances = 1
\$core_instance_name_prefix = "core"

Vagrant.configure("2") do |config|
    config.vm.box = "<%= box_name %>"
    # always use Vagrants insecure key
    config.ssh.insert_key = false
    config.ssh.forward_agent = true

    # Core OS Nodes
    (1..\$core_num_instances).each do |i|
        config.vm.define vm_name = "%s-%02d" % [\$core_instance_name_prefix, i] do |config|
            config.vm.hostname = vm_name

            # Set ip
            ip = "172.17.8.#{i+100}"
            config.vm.network :private_network, ip: ip
            # This tells Ignition what the IP for eth1 (the host-only adapter) should be
            config.ignition.ip = ip

            config.vm.provider :virtualbox do |vb|
                config.ignition.hostname = vm_name
                config.ignition.drive_name = "config" + i.to_s
            end
        end
    end

    config.vm.define vm_name = "hostmaster" do |config|
        config.vm.hostname = vm_name
        ip = "192.168.1.30"
        config.vm.network :private_network, ip: ip
    end
end
EOF

# All operations success exit
echo -e "Success create $box_name
Create new vagrant box with :
vagrant init $box_name --template $HOME/.vagrant.d/templates/Vagrantfile-coreos"
exit 0
