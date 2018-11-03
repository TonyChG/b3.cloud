#!/bin/bash

sed -e 's#enp0s31f6#enp0s25#g' -e 's#+100#+200#g' ../Vagrantfile > ../coreos-vagrant/Vagrantfile
