# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'

Vagrant.require_version ">= 1.6.0"

# Make sure the vagrant-ignition plugin is installed
required_plugins = %w(vagrant-ignition)

$core_num_instances = 1
$core_instance_name_prefix = "core"

Vagrant.configure("2") do |config|
  # always use Vagrants insecure key
  config.ssh.insert_key = false
  config.ssh.forward_agent = true
  config.ssh.username = "core"

  config.vm.box = "coreos-base"

  # Core OS Nodes
  (1..$core_num_instances).each do |i|
      config.vm.define vm_name = "%s-%02d" % [$core_instance_name_prefix, i+100] do |config|
          config.vm.hostname = vm_name

          # Set ip
          ip = "192.168.4.#{i+100}"
          config.vm.network :public_network, ip: ip, bridge: "enp0s31f6"
          # This tells Ignition what the IP for eth1 (the host-only adapter) should be
          config.ignition.ip = ip

          # config.vm.provision "file", source: "user-data", destination: "/var/lib/coreos-vagrant/vagrantfile-user-data"

          config.vm.provider :virtualbox do |vb|
              config.ignition.hostname = vm_name
              config.ignition.drive_name = "config" + i.to_s

              # Second disk in GB
              $second_disksize = 10
              disk = "disks/data#{i}.vdi"
              if !File.exist?(disk)
                  vb.customize ['createhd', '--filename', disk, '--size', 1024 * $second_disksize, '--variant', 'Fixed']
                  vb.customize ['modifyhd', disk, '--type', 'writethrough']
              end
              vb.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 0, '--device', 1, '--type', 'hdd', '--medium', disk]
          end
      end
  end

  # Test DNS
  # config.vm.define vm_name = "hostmaster" do |config|
  #     config.vm.hostname = vm_name
  #     ip = "192.168.1.30"
  #     config.vm.network :private_network, ip: ip
  # end
end
