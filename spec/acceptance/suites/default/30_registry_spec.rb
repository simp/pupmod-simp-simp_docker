# This test is to declare functionality of Docker on EL7 machines.
#
# This module needs to install Docker, and be able to run:
#   - use a complicated docker::run to run a container registry
#   - use the SIMP iptables module to open the port
#   - each host should upload their custom nginx container to the registry
#   - each host should run every custom nginc container
#   - each host should be able to curl all custom nginx containers on all hosts
#
require 'spec_helper_acceptance'

test_name 'docker'

describe 'docker' do
  hosts_array = hosts_with_role(hosts,'docker')
  registry    = fact_on(only_host_with_role(hosts,'registry'), 'fqdn')

  let(:manifest) { <<-EOS
    class { 'iptables':
      ignore => [ 'DOCKER','docker' ]
    }
    iptables::listen::tcp_stateful { 'ssh':
      trusted_nets => ['0.0.0.0/0'],
      dports       => [22]
    }
    iptables::listen::tcp_stateful { 'docker registry':
      trusted_nets => ['0.0.0.0/0'],
      dports       => [5000]
    }

    include 'simp_docker'
    EOS
  }

  context 'set up the registry' do
    hosts_with_role(hosts,'registry').each do |host|
      fqdn = fact_on(host, 'fqdn')
      it 'should start the basic registry container' do
        run_manifest = manifest + <<-EOF
          file { '/tmp/auth': ensure => 'directory' }
          file { '/tmp/auth/htpasswd':
            content => 'testuser:$2y$05$5.l/Dz1q9NaQH4X9pIOd6epSaYFYekkO7lLVcEz7/Kdy1AL8mBlIi',
          }
          docker::run { 'registry':
            image   => 'registry',
            ports   => ['5000:5000'],
            volumes => [
              '/etc/pki/simp-testing/pki/:/etc/pki-testing:Z',
              '/tmp/auth:/auth:Z'
            ],
            env     => [
              'REGISTRY_HTTP_ADDR=0.0.0.0:5000',
              'REGISTRY_HTTP_TLS_CERTIFICATE=/etc/pki-testing/private/#{fqdn}.pem',
              'REGISTRY_HTTP_TLS_KEY=/etc/pki-testing/private/#{fqdn}.pem',
              'REGISTRY_AUTH=htpasswd',
              'REGISTRY_AUTH_HTPASSWD_REALM=Beaker Realm',
              'REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd'
            ],
            require => File['/tmp/auth/htpasswd']
          }
        EOF
        apply_manifest_on(host, run_manifest)
        sleep 20
        apply_manifest_on(host, run_manifest, catch_failures: true)
        sleep 20
        apply_manifest_on(host, run_manifest, catch_changes: true)
      end
    end
  end

  context 'use the registry and push to it' do
    hosts_array.each do |host|
      it 'trust the testing CA' do
        on(host, 'cat /etc/pki/simp-testing/pki/cacerts/cacerts.pem >> /etc/pki/tls/certs/ca-bundle.crt')
        on(host, 'systemctl restart docker')
        sleep 5 # Wait for the daemon to come back up
      end

      it 'use the module to use the local registry' do
        run_manifest = manifest + <<-EOF
          docker::registry { '#{registry}:5000':
            username  => 'testuser',
            password  => 'testpassword',
            # simplib::passgen can be used to generate this hash
            # It must be generated and passed because the upstream module doesn't do it
            # in a way that works on FIPS
            pass_hash => '$6$root$hBfC7VdTd3zj5MlJ6YkwXuhA01VERIVz3b0Ar.EOyMgbXqgsIi9AELXnRvfyBFSYn4aAg9Y56B4rmwfMMrJHr/'
          }
        EOF
        apply_manifest_on(host, run_manifest)
        sleep 20
        apply_manifest_on(host, run_manifest, catch_failures: true)
        # The docker::registry class is not idempotent
        # https://github.com/puppetlabs/puppetlabs-docker/issues/15
        # It should be now
        apply_manifest_on(host, run_manifest, catch_changes: true)
      end

      it 'should push each hosts custom image to the registry' do
        on(host, "docker tag custom_nginx_#{host} #{registry}:5000/custom_nginx_#{host}")
        on(host, "docker push #{registry}:5000/custom_nginx_#{host}")
      end
    end
  end

  context 'pull from the registry' do
    it 'should run all custom containers on all hosts' do
      hosts_array.each do |host|
        run_manifest = manifest
        hosts_array.each_with_index do |instance,i|
          run_manifest += <<-EOF
            docker::run { 'custom_nginx_#{instance}':
              image  => '#{registry}:5000/custom_nginx_#{instance}',
              ports  => ['808#{i}:80'],
            }
            iptables::listen::tcp_stateful { 'custom_nginx_#{instance}':
              trusted_nets => ['0.0.0.0/0'],
              dports       => [808#{i}]
            }
          EOF
        end
        apply_manifest_on(host, run_manifest)
        sleep 20
        apply_manifest_on(host, run_manifest, catch_failures: true)
        sleep 20
        apply_manifest_on(host, run_manifest, catch_changes: true)
      end
    end
    it 'should be running each container on each host' do
      hosts_array.each do |host|
        hosts_array.each_with_index do |instance,i|
          result = retry_on(host, "curl localhost:808#{i}", max_retries: 8, verbose: true).stdout
          expect(result).to match(/Hello from Docker on SIMP/)
        end
      end
    end
  end
end
