require 'spec_helper_acceptance'

test_name 'docker using redhat provided packages'

describe 'docker using redhat provided packages' do

  let(:manifest) { <<-EOS
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

  context 'basic docker usage' do
    hosts.each do |host|
      it 'should apply with no errors' do
        on(host, 'yum install -y epel-release', run_in_parallel: true)
        # Set up base modules and hieradata
        # set_hieradata_on( host,hieradata)
        apply_manifest_on(host, manifest, catch_failures: true, run_in_parallel: true)
        apply_manifest_on(host, manifest, catch_changes: true, run_in_parallel: true)
      end

      it 'should run hello-world via cli' do
        on(host, 'docker run hello-world', run_in_parallel: true)
      end

      it 'should run hello-world via puppet' do
        run_manifest = manifest + <<-EOF
          docker::run { 'hello-world':
            image => 'hello-world'
          }
        EOF
        # this will never be idempotent because of the container used
        apply_manifest_on(host, run_manifest, catch_failures: true, run_in_parallel: true)
        apply_manifest_on(host, run_manifest, catch_failures: true, run_in_parallel: true)
      end

      context 'should run nginx and get a response' do
        it 'configure the stock container' do
          run_manifest = manifest + <<-EOF
            docker::run { 'bare_nginx':
              image => 'nginx',
              ports => ['80:80'],
            }
          EOF
          apply_manifest_on(host, run_manifest, catch_failures: true, run_in_parallel: true)
          apply_manifest_on(host, run_manifest, catch_changes: true, run_in_parallel: true)
          result = retry_on(host, 'curl localhost:80').stdout
          expect(result).to match(/Thank you for using nginx/)
        end

        it 'should stop the service' do
          run_manifest = manifest + <<-EOF
            docker::run { 'bare_nginx':
              image => 'nginx',
              ensure => 'absent'
            }
          EOF
          apply_manifest_on(host, run_manifest, catch_failures: true, run_in_parallel: true)
          apply_manifest_on(host, run_manifest, catch_changes: true, run_in_parallel: true)
        end
      end

      context 'building a custom image' do
        it 'should build and run an image' do
          run_manifest = manifest + <<-EOF
            $web_content = @("END")
              Hello from Docker on SIMP!
              I was built on ${facts['fqdn']}!
              | END
            $dockerfile = @(END)
              FROM nginx
              COPY index.html /usr/share/nginx/html/index.html
              | END
            file { '/root/index.html':
              content => $web_content
            }
            file { '/root/Dockerfile':
              content => $dockerfile,
              require => File['/root/index.html']
            }
            docker::image { 'custom_nginx_#{host}':
              docker_dir => '/root',
              require    => File['/root/Dockerfile']
            }

            docker::run { 'custom_nginx_#{host}':
              image => 'custom_nginx_#{host}',
              ports => ['80:80'],
            }
          EOF
          apply_manifest_on(host, run_manifest, catch_failures: true, run_in_parallel: true)
          apply_manifest_on(host, run_manifest, catch_changes: true, run_in_parallel: true)
          result = retry_on(host, 'curl localhost:80').stdout
          expect(result).to match(/Hello from Docker on SIMP/)
        end

        it 'should stop the service' do
          run_manifest = manifest + <<-EOF
            docker::run { 'custom_nginx_#{host}':
              image  => 'custom_nginx_#{host}',
              ensure => 'absent'
            }
          EOF
          apply_manifest_on(host, run_manifest, catch_failures: true, run_in_parallel: true)
          apply_manifest_on(host, run_manifest, catch_changes: true, run_in_parallel: true)
        end
      end
    end
  end
end
