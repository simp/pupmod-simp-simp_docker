require 'spec_helper'


describe 'simp_docker' do

  default_parameters = {
    use_upstream_package_source: false,
    service_overrides_template: false,
    selinux_enabled: true,
    docker_ce_package_name: 'docker',
    log_driver: 'journald',
    docker_group: 'dockerroot',
    socket_group: 'dockerroot',
  }

  oel_parameters = default_parameters.dup.merge(
    manage_package: false,
    docker_ce_package_name: 'docker-engine'
  )

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) do
        facts = os_facts
        facts[:networking] = {
          interfaces: {
            lo: nil,
            em1: nil
          }
        }
        facts[:selinux] = true
        facts
      end

      let(:class_params) {
        if os_facts[:os][:name] == 'OracleLinux'
          oel_parameters.dup
        else
          default_parameters.dup
        end
      }

      context 'simp_docker class without any parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('docker').with(class_params) }
        it { is_expected.not_to contain_sysctl('net.bridge.bridge-nf-call-iptables') }
        it { is_expected.not_to contain_sysctl('net.bridge.bridge-nf-call-ip6tables') }
      end

      context 'after docker0 has been created' do
        let(:facts) {
          os_facts.merge(
            networking: {
              interfaces: {
                lo: nil,
                em1: nil,
                docker0: nil
              }
            }
          )
        }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_sysctl('net.bridge.bridge-nf-call-iptables') }
        it { is_expected.to contain_sysctl('net.bridge.bridge-nf-call-ip6tables') }
      end

      context 'simp_docker with the redhat release_type and options' do
        let(:params) {{
          release_type: 'redhat',
          options: {
            dns: ['8.8.8.8'],
            log_level: 'info',
            docker_group: 'not_dockerroot'
          }
        }}
        let(:class_params) {
          if os_facts[:os][:name] == 'OracleLinux'
            oel_parameters.dup
          else
            default_parameters.dup
          end
        }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('docker').with(class_params.merge(
          dns: ['8.8.8.8'],
          log_level: 'info',
          docker_group: 'not_dockerroot',
          socket_group: 'not_dockerroot',
        )) }
      end

      context 'simp_docker with the ce release_type and options' do
        let(:params) {{
          release_type: 'ce',
          options: {
            dns: ['8.8.8.8'],
            log_level: 'info'
          }
        }}
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('docker').with(
          # selinux_enabled: "true",
          docker_ce_package_name: 'docker-ce',
          log_driver: 'journald',
          dns: ['8.8.8.8'],
          log_level: 'info'
        ) }
      end

      context 'simp_docker with the ee release_type and options' do
        pending 'not sure how to test docker-ee for free'
      end
    end
  end
end
