#
class simp_docker::iptables {
  assert_private()

  $bridge_dev = $simp_docker::docker_bridge_dev

  $_iptables_rule = @("EOF")
    -A FORWARD -j DOCKER-ISOLATION
    -A FORWARD -o ${bridge_dev} -j DOCKER
    -A FORWARD -o ${bridge_dev} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    -A FORWARD -i ${bridge_dev} ! -o ${bridge_dev} -j ACCEPT
    -A FORWARD -i ${bridge_dev} -o ${bridge_dev} -j ACCEPT
    -A DOCKER-ISOLATION -j RETURN
    | EOF

  iptables::rule { 'Allow Docker IPtables rules':
    content  => $_iptables_rule,
    first    => true,
    absolute => true,
    comment  => 'Docker Required Rules',
    header   => false,
    apply_to => 'ipv4'
  }

}
