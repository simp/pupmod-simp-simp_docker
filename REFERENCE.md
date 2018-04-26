# Reference

## Classes
* [`simp_docker`](#simp_docker): Helpers class to ease use of puppetlabs/docker
## Classes

### simp_docker

Helpers class to ease use of puppetlabs/docker


#### Parameters

The following parameters are available in the `simp_docker` class.

##### `release_type`

Data type: `Simp_docker::Type`

The type of Docker to be managed
Possible values:
  'redhat': RedHat packaged Docker
  'ce':     Docker Community Edition
  'ee':     Docker Enterprise Edition (Untested due to licensing)

##### `manage_sysctl`

Data type: `Boolean`

Manage the sysctl rules required for container networking

##### `bridge_dev`

Data type: `String`

The network device Docker will use
This is only needed to check to see if it's possible to add the sysctl rules.

##### `default_options`

Data type: `Hash`

Default parameters for the upstream `docker` class.
If there is any friction here between this module and he upstream module,
it is a bug.

These parameters will be overwritten by $options if set there, so
please use that parameter instead.

##### `options`

Data type: `Optional[Hash]`

Other options to be sent to the `docker` class.
@see https://github.com/puppetlabs/puppetlabs-docker/tree/1.0.2#usage

This parameter will overwrite and default setting in $default_options.


