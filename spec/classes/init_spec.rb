require 'spec_helper'

describe 'simp_docker' do

  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts
        end

        context 'simp_docker class without any parameters' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('docker').with(
            use_upstream_package_source: false,
            service_overrides_template: false,
            selinux_enabled: "true",
            manage_epel: false,
            package_name: 'docker',
            log_driver: 'journald',
            docker_group: 'dockerroot',
          ) }
          it { is_expected.to contain_sysctl('net.bridge.bridge-nf-call-iptables') }
          it { is_expected.to contain_sysctl('net.bridge.bridge-nf-call-ip6tables') }
        end

        context 'simp_docker with the redhat release_type and options' do
          let(:params) {{
            release_type: 'redhat',
            other_options: {
              dns: ['8.8.8.8'],
              log_level: 'info'
            }
          }}
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('docker').with(
            use_upstream_package_source: false,
            service_overrides_template: false,
            selinux_enabled: "true",
            manage_epel: false,
            package_name: 'docker',
            log_driver: 'journald',
            docker_group: 'dockerroot',
            dns: ['8.8.8.8'],
            log_level: 'info'
          ) }
          it { is_expected.to contain_sysctl('net.bridge.bridge-nf-call-iptables') }
          it { is_expected.to contain_sysctl('net.bridge.bridge-nf-call-ip6tables') }
        end

        context 'simp_docker with the ce release_type and options' do
          let(:params) {{
            release_type: 'ce',
            other_options: {
              dns: ['8.8.8.8'],
              log_level: 'info'
            }
          }}
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('docker').with(
            # selinux_enabled: "true",
            manage_epel: false,
            package_name: 'docker-ce',
            log_driver: 'journald',
            dns: ['8.8.8.8'],
            log_level: 'info'
          ) }
          it { is_expected.to contain_sysctl('net.bridge.bridge-nf-call-iptables') }
          it { is_expected.to contain_sysctl('net.bridge.bridge-nf-call-ip6tables') }
        end

        context 'simp_docker with the ee release_type and options' do
          pending 'not sure how to test docker-ee for free'
        end
      end
    end
  end
end
