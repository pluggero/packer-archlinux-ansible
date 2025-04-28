# Archlinux Packer Template for Ansible Role Testing

[![Build](https://github.com/pluggero/packer-archlinux-ansible/actions/workflows/build.yml/badge.svg)](https://github.com/pluggero/packer-archlinux-ansible/actions/workflows/build.yml)

## Supported Hypervisor Platforms

- VirtualBox

## Quick Start

### Requirements

- At least one of the supported Hypervisor platforms
- Vagrant

### Installation

- Take a look at https://portal.cloud.hashicorp.com/vagrant/discover/pluggero/archlinux-ansible to get started with the Vagrant box.

## Creating your own box

1. Make sure you met the requirements above
2. Clone this repository
3. Create virtual python environment
4. Install dependencies
5. Run the build script to create the box in the `packer/outputs` directory:

```bash
scripts/archlinux_builder.sh
```

## License

MIT / BSD

## Author Information

This role was created in 2025 by Robin Plugge.<br>
The bootstrap script was inspired by [@ProfessorManhattan](https://github.com/ProfessorManhattan/packer-archlinux-desktop)
