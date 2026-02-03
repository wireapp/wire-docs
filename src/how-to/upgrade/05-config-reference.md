# Configuration Reference

## Overview

These references outline configuration changes between `wire-server` versions.
It is intended for users who:

- Maintain custom deployment templates
- Use non-standard `wire-server-deploy` Ansible/Helm deployment
- Need to know exact configuration changes to adapt their setups

## Categories

- Known bugs - known bugs regarding charts deployment and how to work around it, if possible
- Mandatory (breaking) changes - configuration changes that **must** be applied or services will fail to start
- Optional changes - new features, enhancements or monitoring/logging options
- Deprecated - configuration settings that can be removed or omitted, have no impact on the upgrade

## How to use

### Identify your versions

- Current version you are running
- Target version you want to upgrade to

### Review all intermediate versions

Configuration changes are cumulative. Review each version reference for mandatory changes.

### Apply config to your templates

Apply each configuration change to your templates as applicable to your model.

## References

- [Wire Server 5.24.0](config-references/wire-server-5.24.0.md)
- [Wire Server 5.25.0](config-references/wire-server-5.25.0.md)

## Contributing

If you find configuration changes not documented here, please report them to us directly or through a GitHub issue in our [documentation repository](https://github.com/wireapp/wire-docs). Include version numbers, configuration section and exact change needed.
