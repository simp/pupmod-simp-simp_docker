# Helpers class to ease use of puppetlabs/docker
#
# @param release_type The type of Docker to be managed
#   Possible values:
#     'redhat': RedHat packaged Docker
#     'ce':     Docker Community Edition
#     'ee':     Docker Enterprise Edition (Untested due to licensing)
#
#
# @param manage_sysctl Manage the sysctl rules required for container networking
#
# @param bridge_dev The network device Docker will use
#   This is only needed to check to see if it's possible to add the sysctl rules.
#
# @param default_options Default parameters for the upstream `docker` class.
#   If there is any friction here between this module and he upstream module,
#   it is a bug.
#
#   These parameters will be overwritten by $options if set there, so
#   please use that parameter instead.
#
# @param options Other options to be sent to the `docker` class.
#   @see https://github.com/puppetlabs/puppetlabs-docker/tree/1.0.2#usage
#
#   This parameter will overwrite and default setting in $default_options.
#
# @author https://github.com/simp/pupmod-simp-simp_docker/graphs/contributors
#
class simp_docker (
  Simp_docker::Type $release_type,
  Boolean $manage_sysctl,
  String $bridge_dev,

  Hash $default_options,
  Optional[Hash] $options,
) {

  # TODO: remove this block after SIMP-4261 is satisfied
  # Need to account for changing the docker_group in one of the options hashes
  # This functionality has been implemented in the upstream module and this code can
  # be removed when it's released. See SIMP-4261.
  if $options and $options['docker_group'] and !$options['socket_group'] {
    $_socket_group_option = {
      'socket_group' => $options['docker_group']
    }
  }
  elsif $default_options[$release_type] and $default_options[$release_type]['docker_group']  and !$default_options[$release_type]['socket_group'] {
    $_socket_group_option = {
      'socket_group' => $default_options[$release_type]['docker_group']
    }
  }
  else {
    $_socket_group_option = {}
  }

  $_docker_bridge_up = ($bridge_dev in $facts['networking']['interfaces'].keys)
  if $manage_sysctl and $_docker_bridge_up {
    sysctl {
      default:
        before => Class['docker'];
      'net.bridge.bridge-nf-call-iptables':  value => 1 ;
      'net.bridge.bridge-nf-call-ip6tables': value => 1 ;
    }
  }

  class { 'docker':
    * => $default_options[$release_type] + $_socket_group_option + $options
  }
}
