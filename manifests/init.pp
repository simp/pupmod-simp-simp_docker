#
class simp_docker (
  Simp_docker::Type $type,

  Hash $default_options,
  Optional[Hash] $other_options,

  Boolean $iptables = simplib::lookup('simp_options::firewall', { 'default_value' => true }),
) {

  # include "simp_docker::${type}"

  class { 'docker':
    * => $default_options[$type] + $other_options
  }
}
