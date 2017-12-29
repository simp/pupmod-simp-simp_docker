# This test is to declare functionality of Docker on EL7 machines.
#
# This module needs to install Docker, and be able to run:
#   - the 'hello-world' container, from Puppet
#   - the stock 'nginx' container, from Puppet
#   - build a custom 'nginx' container, built with Puppet
#   - run the custom 'nginx' container and curl it
#
require 'spec_helper_acceptance'

test_name 'docker using redhat provided packages'

describe 'docker using redhat provided packages' do

  let(:manifest) { <<-EOS
      include 'simp_docker'
    EOS
  }

  context 'basic docker usage' do
    hosts.each do |host|
      it 'should apply with no errors' do
        on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
        on(host, 'echo "root:password" | chpasswd --crypt-method SHA256')

        on(host, 'yum install -y epel-release', run_in_parallel: true)

        set_hieradata_on(host, { 'simp_options::firewall' => true })
        apply_manifest_on(host, manifest, run_in_parallel: true)
        apply_manifest_on(host, manifest, catch_failures: true, run_in_parallel: true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true, run_in_parallel: true)
      end

      it 'should set the group of the docker socket to dockerroot' do
        group = on(host, 'stat -c %G /var/run/docker.sock').stdout.strip
        expect(group).to eq('dockerroot')
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
          sleep 20
          apply_manifest_on(host, run_manifest, catch_failures: true, run_in_parallel: true)
          sleep 20
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
          sleep 20
          apply_manifest_on(host, run_manifest, catch_failures: true, run_in_parallel: true)
          sleep 20
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
