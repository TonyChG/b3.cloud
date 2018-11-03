# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'

Vagrant.require_version ">= 1.6.0"

# Make sure the vagrant-ignition plugin is installed
required_plugins = %w(vagrant-ignition)

plugins_to_install = required_plugins.select { |plugin| not Vagrant.has_plugin? plugin }
if not plugins_to_install.empty?
  puts "Installing plugins: #{plugins_to_install.join(' ')}"
  if system "vagrant plugin install #{plugins_to_install.join(' ')}"
    exec "vagrant #{ARGV.join(' ')}"
  else
    abort "Installation of one or more plugins has failed. Aborting."
  end
end

CLOUD_CONFIG_PATH = File.join(File.dirname(__FILE__), "user-data")
IGNITION_CONFIG_PATH = File.join(File.dirname(__FILE__), "config.ign")
CONFIG = File.join(File.dirname(__FILE__), "config.rb")

# Defaults for config options defined in CONFIG
$num_instances = 1
$update_channel = "alpha"
$instance_name_prefix = "core"
$enable_serial_logging = false
$share_home = false
$vm_gui = false
$vm_memory = 1024
$vm_cpus = 1
$vb_cpuexecutioncap = 100
$shared_folders = {}
$forwarded_ports = {}

# Attempt to apply the deprecated environment variable NUM_INSTANCES to
# $num_instances while allowing config.rb to override it
if ENV["NUM_INSTANCES"].to_i > 0 && ENV["NUM_INSTANCES"]
  $num_instances = ENV["NUM_INSTANCES"].to_i
end

if File.exist?(CONFIG)
  require CONFIG
end

# Use old vb_xxx config variables when set
def vm_gui
  $vb_gui.nil? ? $vm_gui : $vb_gui
end

def vm_memory
  $vb_memory.nil? ? $vm_memory : $vb_memory
end

def vm_cpus
  $vb_cpus.nil? ? $vm_cpus : $vb_cpus
end

Vagrant.configure("2") do |config|
  # always use Vagrants insecure key
  config.ssh.insert_key = false
  # forward ssh agent to easily ssh into the different machines
  config.ssh.forward_agent = true

  config.vm.box = "coreos-#{$update_channel}"
  config.vm.box_url = "https://#{$update_channel}.release.core-os.net/amd64-usr/current/coreos_production_vagrant_virtualbox.json"

  ["vmware_fusion", "vmware_workstation"].each do |vmware|
    config.vm.provider vmware do |v, override|
      override.vm.box_url = "https://#{$update_channel}.release.core-os.net/amd64-usr/current/coreos_production_vagrant_vmware_fusion.json"
    end
  end

  config.vm.provider :virtualbox do |v|
    # On VirtualBox, we don't have guest additions or a functional vboxsf
    # in CoreOS, so tell Vagrant that so it can be smarter.
    v.check_guest_additions = false
    v.functional_vboxsf     = false
    # enable ignition (this is always done on virtualbox as this is how the ssh key is added to the system)
    config.ignition.enabled = true
  end

  # plugin conflict
  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end

  (1..$num_instances).each do |i|
    config.vm.define vm_name = "%s-%02d" % [$instance_name_prefix, i+100] do |config|
      config.vm.hostname = vm_name

      # Reconfigure daemon
      config.vm.provision "file", source: "../configs/docker/daemon.json", destination: "/tmp/daemon.json"
      config.vm.provision "shell" do |s|
          s.inline = "cp /tmp/daemon.json /etc/docker/daemon.json"
          s.privileged = true
      end
      # Mount lvm volume
      config.vm.provision "volume", type: "shell", run: "once",
          :path => "../scripts/create_data_volume.sh"

      if $expose_docker_tcp
        config.vm.network "forwarded_port", guest: 2375, host: ($expose_docker_tcp + i - 1), host_ip: "127.0.0.1", auto_correct: true
      end

      $forwarded_ports.each do |guest, host|
        config.vm.network "forwarded_port", guest: guest, host: host, auto_correct: true
      end

      config.vm.provider :virtualbox do |vb|
        vb.gui = vm_gui
        vb.memory = vm_memory
        vb.cpus = vm_cpus
        vb.customize ["modifyvm", :id, "--cpuexecutioncap", "#{$vb_cpuexecutioncap}"]
        config.ignition.config_obj = vb

        # Second disk in GB
        $second_disksize = 10
        disk = "../disks/data#{i}.vdi"
        if !File.exist?(disk)
            vb.customize ['createhd', '--filename', disk, '--size', 1024 * $second_disksize, '--variant', 'Fixed']
            vb.customize ['modifyhd', disk, '--type', 'writethrough']
        end
        vb.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 0, '--device', 1, '--type', 'hdd', '--medium', disk]
      end

      ip = "172.17.8.#{i+100}"
      config.vm.network "public_network", ip: "192.168.4.#{i+100}", bridge: "enp0s31f6"
      config.vm.network :private_network, ip: ip
      # This tells Ignition what the IP for eth1 (the host-only adapter) should be
      config.ignition.ip = ip

      # Uncomment below to enable NFS for sharing the host machine into the coreos-vagrant VM.
      #config.vm.synced_folder ".", "/home/core/share", id: "core", :nfs => true, :mount_options => ['nolock,vers=3,udp']
      $shared_folders.each_with_index do |(host_folder, guest_folder), index|
        config.vm.synced_folder host_folder.to_s, guest_folder.to_s, id: "core-share%02d" % index, nfs: true, mount_options: ['nolock,vers=3,udp']
      end

      if $share_home
        config.vm.synced_folder ENV['HOME'], ENV['HOME'], id: "home", :nfs => true, :mount_options => ['nolock,vers=3,udp']
      end

      # This shouldn't be used for the virtualbox provider (it doesn't have any effect if it is though)
      if File.exist?(CLOUD_CONFIG_PATH)
        config.vm.provision :file, :source => "#{CLOUD_CONFIG_PATH}", :destination => "/tmp/vagrantfile-user-data"
        config.vm.provision :shell, inline: "mkdir -p /var/lib/coreos-vagrant", :privileged => true
        config.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
      end

      config.vm.provider :virtualbox do |vb|
        config.ignition.hostname = vm_name
        config.ignition.drive_name = "config" + i.to_s
        # when the ignition config doesn't exist, the plugin automatically generates a very basic Ignition with the ssh key
        # and previously specified options (ip and hostname). Otherwise, it appends those to the provided config.ign below
        if File.exist?(IGNITION_CONFIG_PATH)
          config.ignition.path = 'config.ign'
        end
      end
    end
  end
end
