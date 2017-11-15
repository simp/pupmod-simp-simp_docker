require 'spec_helper_acceptance'

test_name 'docker'

describe 'docker' do
  hosts_array = hosts_with_role(hosts,'docker')
  registry    = fact_on(only_host_with_role(hosts,'registry'), 'fqdn')

  let(:manifest) { <<-EOS
      sysctl {'net.bridge.bridge-nf-call-iptables':  value => 1 }
      sysctl {'net.bridge.bridge-nf-call-ip6tables': value => 1 }
      sysctl {'net.bridge.bridge-nf-call-iptables':  value => 1 }
      sysctl {'net.bridge.bridge-nf-call-ip6tables': value => 1 }
      class { 'simp_docker':
        type   => 'redhat',
        before => [
          Sysctl['net.bridge.bridge-nf-call-iptables'],
          Sysctl['net.bridge.bridge-nf-call-ip6tables']
        ]
      }
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
              '/etc/pki/simp-testing/pki/:/etc/pki-testing',
              '/tmp/auth:/auth'
            ],
            env     => [
              'REGISTRY_HTTP_ADDR=0.0.0.0:5000',
              'REGISTRY_HTTP_TLS_CERTIFICATE=/etc/pki-testing/private/#{fqdn}.pem',
              'REGISTRY_HTTP_TLS_KEY=/etc/pki-testing/private/#{fqdn}.pem',
              'REGISTRY_AUTH=htpasswd',
              '"REGISTRY_AUTH_HTPASSWD_REALM=Beaker Realm"',
              'REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd'
            ],
            require => File['/tmp/auth/htpasswd']
          }
        EOF
        apply_manifest_on(host, run_manifest, catch_failures: true)
        apply_manifest_on(host, run_manifest, catch_changes: true)
      end
      it 'should open port 5000' do
        on(host, 'iptables -A INPUT -p tcp --dport 5000 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT')
        on(host, 'iptables -A OUTPUT -p tcp --sport 5000 -m conntrack --ctstate ESTABLISHED -j ACCEPT')
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
            username => 'testuser',
            password => 'testpassword'
          }
        EOF
        apply_manifest_on(host, run_manifest)
        apply_manifest_on(host, run_manifest, catch_failures: true)
        # The docker::registry class is not idempotent
        # https://github.com/puppetlabs/puppetlabs-docker/issues/15
        # apply_manifest_on(host, run_manifest, catch_changes: true)
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
            # DOESN'T WORK FOR NOW
            # include 'iptables'
            # iptables::listen::tcp_stateful { 'custom_nginx_#{instance}':
            #   trusted_nets => ['ANY'],
            #   dports       => [808#{i}]
            # }
          EOF
          on(host, "iptables -A INPUT -p tcp --dport 808#{i} -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT")
          on(host, "iptables -A OUTPUT -p tcp --sport 808#{i} -m conntrack --ctstate ESTABLISHED -j ACCEPT")
        end
        apply_manifest_on(host, run_manifest, catch_failures: true)
        apply_manifest_on(host, run_manifest, catch_changes: true)
      end
    end
    it 'should be running each container on each host' do
      hosts_array.each do |host|
        hosts_array.each_with_index do |instance,i|
          result = retry_on(host, "curl localhost:808#{i}").stdout
          expect(result).to match(/Hello from Docker on SIMP/)
        end
      end
    end
  end
end
