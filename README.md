# TP1 - Cloud
> Formateur: Léo GODEFROY
> Groupe: Antoine CHINT - Benjamin GIRALT

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
scripts/create_coreos_basebox.sh
```

## Usage

```
vagrant up
```
