# Quick Start

This is a quick guide on how to get started with Effortless.

## Effortless Config

1. Install [Chef Workstation](https://downloads.chef.io/chef-workstation)
1. Install [Chef Habitat](https://www.habitat.sh/docs/install-habitat/)
1. Configure Chef Habitat on your workstation by running `hab setup`
1. Change Directory into `examples/effortless_config/chef_repo_pattern`
1. Change the line 26 of the `kitchen.yml` file to use your origin:

   ```yml
   provisioner:
     arguments: ["<Your Origin>", "effortless-config-baseline"]
   ```

1. Build the package with the command: `hab pkg build .`
1. Run Test Kitchen to see the cookbook work:

   ```bash
   kitchen converge base-centos
   ```