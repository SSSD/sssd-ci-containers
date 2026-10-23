# SSSD CI Containers Ansible Setup

## Purpose

This Ansible project roles and playbooks are provided to build out the set of
containers needed for SSSD testing.  They can also be used to setup an already
provisioned environment with all of the necessary test requirements and
dependencies.

## Running manually

```console
$ sudo ansible-playbook -i inventory-up.yml -vvv $(pwd)/playbook_selenium.yml
```

## Running in CI against other provisioned systems

Most of the time these ansible roles and playbooks will be used in CI jobs
instead of manually.  In those cases, you must generate a compatible
inventory.yaml file for use with the roles provided here.  Once a compatible
inventory file is available, **ansible-playbook** can be run to execute the
**playbook_vm.yml** playbook:

```console
$ sudo ansible-playbook -i generated_inventory.yml -v $(pwd)/playbook_vm.yml
```
