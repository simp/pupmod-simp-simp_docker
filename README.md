[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/simp_docker.svg)](https://forge.puppetlabs.com/simp/simp_docker)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/simp_docker.svg)](https://forge.puppetlabs.com/simp/simp_docker)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-simp_docker.svg)](https://travis-ci.org/simp/pupmod-simp-simp_docker)

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with simp_docker](#setup)
   * [What simp_docker affects](#what-simp_docker-affects)
   * [Setup requirements](#setup-requirements)
   * [Beginning with simp_docker](#beginning-with-simp_docker)
3. [Usage - Configuration options and additional functionality](#usage)
   * [`docker::run` - Running containers as a systemd service](#dockerrun)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)
   * [Acceptance Tests - Beaker env variables](#acceptance-tests)


## Description

`simp_docker` is a helper module to get Docker up and running on SIMP systems.
The goal of this project is to not get in the way of anyone experienced with
Docker, and to not set up Docker in a way that would not make sense to anyone
using Docker on other platforms.

It currently supports installing Docker through the RedHat-provided `docker`
package (recommended) or the Docker-provided `docker-ce` package.

The meat of this module is to provide SIMP-specific defaults for the very good
upstream [puppetlabs/docker](https://github.com/puppetlabs/puppetlabs-docker)
module.


### This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com),
a compliance-management framework built on Puppet.

If you find any issues, they may be submitted to our [bug
tracker](https://simp-project.atlassian.net/).

This module is optimally designed for use within a larger SIMP ecosystem, but
it can be used independently:

 * When included within the SIMP ecosystem, security compliance settings will
   be managed from the Puppet server.
 * If used independently, all SIMP-managed security subsystems are disabled by
   default and must be explicitly opted into by administrators.  Please review
   the parameters in
   [`simp/simp_options`](https://github.com/simp/pupmod-simp-simp_options) for
   details.


## Setup


### What simp_docker affects

This module will:
  * Install `docker` and related packages
  * Manage the `docker` service

The `puppetlabs/docker` module can:
  * [Manage images][1] available on the local machine
  * Run containers [as systemd services][2]
  * [Manage registries][3] available on the local machine
  * A [bunch of other cool stuff][4]

[1]: https://github.com/puppetlabs/puppetlabs-docker/tree/1.0.2#images
[2]: https://github.com/puppetlabs/puppetlabs-docker/tree/1.0.2#containers
[3]: https://github.com/puppetlabs/puppetlabs-docker/tree/1.0.2#private-registries
[4]: https://github.com/puppetlabs/puppetlabs-docker/tree/1.0.2#usage

**NOTE:** This module only supports EL7.  **It does not support EL6.**

### Known Issues

The RedHat docker executable uses `dockerroot` as the docker_group.
In simp_docker, a class delaration is used to configure the puppetlabs docker module.
This declaration sets the value for the  docker::docker_group variable to `dockerroot`
to work with RedHats implementation of docker.  How ever,
the puppetlabs docker::run module does not have access to this setting and
does not allow the user to set the docker_group.  It mistakenly sets the runtime
group to `docker`.

To work around  this issue the simp_docker profile module
sets the local system groups `docker` and `dockerroot` to the same group id on
RedHat family systems.

See https://github.com/puppetlabs/puppetlabs-docker/issues/321

### Setup Requirements

If you are seeing networking issues with containers running on hosts using this
module and SIMP's iptables module, set the following setting in hieradata:

```yaml
---
iptables::ignore:
  - DOCKER
  - docker
```

This snippet tells the simp/iptables module to ignore rules written to iptables
by the Docker daemon. Otherwise, the iptables module will remove them.

See [the acceptance tests for this project][5] for an example of how to set up
this module for use in a full SIMP environment.

[5]: spec/acceptance/suites/redhat/20_multi_node_spec.rb


### Beginning with simp_docker

To get started with `simp_docker`, include the class and choose the version of
Docker that should be used.

For RedHat-provided Docker (`docker` from `CentOS-Extras`):

```puppet
include 'simp_docker'
```

For Docker Community Edition or Docker-provided docker (`docker-ce`):

```puppet
class { 'simp_docker':
  release_type => 'ce'
}
```


## Usage

The default parameters for each `release_type` are kept in [module
data](data/common.yaml). If these are wrong or need to be updated, please file
an [issue](https://simp-project.atlassian.net).

If more advanced settings are required, all options set in the `options` hash
will be passed to the `puppetlabs/docker` docker class. Here is an example
setting up Docker using a TCP socket:

```puppet
class { 'simp_docker':
  # TODO build this into the module using simp_options::pki :)
  options => {
    tcp_bind    => ['tcp://0.0.0.0:4243'],
    socket_bind => 'unix:///var/run/docker.sock',
    tls_enable  => true,
    tls_cacert  => '/etc/pki/simp/x509/cacerts/cacerts.pem',
    tls_cert    => '/etc/pki/simp/x509/private/<hostname>.pem',
    tls_key     => '/etc/pki/simp/x509/public/<hostname>.pub',
  }
}
```


### `docker::run`

An example snippet that runs a container as a systemd service:

```puppet
docker::run { 'stock_nginx':
  image => 'nginx',
  ports => ['80:80'],
}
```

This will create a service called `docker-stock_nginx` which contains a
`docker run` command similar to the following:

```bash
docker run --net bridge -m 0b -p 80:80 --name stock_nginx nginx
```


## Reference

Please refer to the inline documentation within each source file, or to the
module's generated YARD documentation for reference material. The upstream
[`puppetlabs/docker` documentation][6] is also a great resource.

[6]: https://github.com/puppetlabs/puppetlabs-docker/tree/1.0.2

## Limitations

This module only supports EL7.  **It does not support EL6**.

SIMP Puppet modules are generally intended for use on Red Hat Enterprise Linux
and compatible distributions, such as CentOS. Please see the
[`metadata.json` file](./metadata.json) for the most up-to-date list of
supported operating systems, Puppet versions, and module dependencies.


## Development

Please read our [Contribution Guide](https://simp.readthedocs.io/en/stable/contributors_guide/index.html).


### Acceptance tests

This module includes [Beaker](https://github.com/puppetlabs/beaker) acceptance
tests using the SIMP [Beaker Helpers](https://github.com/simp/rubygem-simp-beaker-helpers).
By default the tests use [Vagrant](https://www.vagrantup.com/) with
[VirtualBox](https://www.virtualbox.org) as a back-end; Vagrant and VirtualBox
must both be installed to run these tests without modification. To execute the
tests run the following:

```shell
bundle install
bundle exec rake beaker:suites
```

Please refer to the [SIMP Beaker Helpers documentation](https://github.com/simp/rubygem-simp-beaker-helpers/blob/master/README.md)
for more information.
