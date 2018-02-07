# This test is to declare functionality of Docker on EL7 machines.
#
# This module needs to install Docker, and be able to run:
#   - the 'hello-world' container, from Puppet
#   - run the custom 'nginx' container from the last test
#   - use SIMP's iptables module to open host ports
#   - each host should be able to curl each other's custom nginx container
#
require 'spec_helper_acceptance'

test_name 'docker'

describe 'docker' do

  let(:manifest) { <<-EOS
    class { 'iptables':
      ignore => [ 'DOCKER','docker' ]
    }
    iptables::listen::tcp_stateful { 'ssh':
      trusted_nets => ['0.0.0.0/0'],
      dports       => [22]
    }

    include 'simp_docker'
    EOS
  }

  context 'set up docker on hosts' do
    hosts.each do |host|
      it 'should apply with no errors' do
        apply_manifest_on(host, manifest, catch_failures: true, run_in_parallel: true)
        apply_manifest_on(host, manifest, catch_failures: true, run_in_parallel: true)
        sleep 20
        apply_manifest_on(host, manifest, catch_changes: true, run_in_parallel: true)
      end

      it 'should run hello-world via cli' do
        on(host, 'docker run hello-world', run_in_parallel: true)
      end

      it 'should run a built image' do
        run_manifest = manifest + <<-EOF
          docker::run { 'custom_nginx_#{host}':
            image => 'custom_nginx_#{host}',
            ports => ['80:80'],
          }
          iptables::listen::tcp_stateful { 'custom_nginx_#{host}':
            trusted_nets => ['0.0.0.0/0'],
            dports       => [80]
          }
        EOF
        apply_manifest_on(host, run_manifest, run_in_parallel: true)
        sleep 20
        apply_manifest_on(host, run_manifest, catch_failures: true, run_in_parallel: true)
        sleep 20
        apply_manifest_on(host, run_manifest, catch_changes: true, run_in_parallel: true)
        result = retry_on(host, 'curl localhost:80', verbose: true)
        expect(result.stdout).to match(/Hello from Docker on SIMP/)
      end
    end
  end

  context 'all hosts should be hosting the nginx page on port 80' do
    hosts.permutation(2).to_a.each do |first, second|
      it "#{first} can connect to #{second}" do
        result = retry_on(first, "curl #{second}:80", max_retries: 8, verbose: true).stdout
        expect(result).to match(/Hello from Docker on SIMP/)
        expect(result).to match(/I was built on #{second}/)
     end
    end
  end
end
