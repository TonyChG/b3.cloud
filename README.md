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
```

## Usage

```
vagrant init coreos-base --template $HOME/.vagrant.d/templates/Vagrantfile-coreos"
vagrant up
```
