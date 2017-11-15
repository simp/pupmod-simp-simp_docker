#
class simp_docker (
  Simp_docker::Type $release_type,
  Boolean $manage_sysctl,

  Hash $default_options,
  Optional[Hash] $other_options,

  Boolean $iptables = simplib::lookup('simp_options::firewall', { 'default_value' => true }),
) {

  # include "simp_docker::${type}"

  if $manage_sysctl {
    sysctl {
      'net.bridge.bridge-nf-call-iptables': value  => 1 ;
      'net.bridge.bridge-nf-call-ip6tables': value  => 1 ;
    }
  }

  class { 'docker':
    * => $default_options[$release_type] + $other_options
  }
}
