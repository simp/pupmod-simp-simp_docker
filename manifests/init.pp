#
class simp_docker (
  Simp_docker::Type $release_type,
  Boolean $manage_sysctl,
  String $docker_bridge_dev,
  # Boolean $iptables_hack,

  Hash $default_options,
  Optional[Hash] $other_options,
) {

  # include "simp_docker::${type}"
  $_docker_bridge_up = ($docker_bridge_dev in $facts['networking']['interfaces'].keys)
  if $manage_sysctl and $_docker_bridge_up {
    sysctl {
      default:
        before => Class['docker'];
      'net.bridge.bridge-nf-call-iptables':  value => 1 ;
      'net.bridge.bridge-nf-call-ip6tables': value => 1 ;
    }
  }

  # if $iptables_hack {
  #   include 'iptables'
  #
  #   exec { 'add docker chain back':
  #     command     => '/sbin/iptables -t filter -N DOCKER || /usr/bin/true',
  #     # unless      => '/sbin/iptables -t nat -nvL | /usr/bin/grep DOCKER',
  #     refreshonly => true,
  #     subscribe   => Iptables_optimize['/etc/sysconfig/iptables']
  #   }
  # }

  class { 'docker':
    * => $default_options[$release_type] + $other_options
  }
}
