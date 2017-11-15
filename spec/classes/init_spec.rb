require 'spec_helper'

describe 'simp_docker' do
  shared_examples_for "a structured module" do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_class('simp_docker') }
    it { is_expected.to contain_class('simp_docker') }
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts
        end

        context "simp_docker class without any parameters" do
          it { is_expected.to compile.with_all_deps }
        end
      end
    end
  end
end
