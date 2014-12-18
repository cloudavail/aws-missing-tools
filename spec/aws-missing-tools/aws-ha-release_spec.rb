require 'spec_helper'

module AwsMissingTools
  describe AwsHaRelease do
    let(:aws_ha_release) { AwsHaRelease.new(%w())}

    describe '#validate_options' do
      it 'requires an auto scaling group' do
        expect { aws_ha_release.validate_options({}) }.to raise_error OptionParser::MissingArgument
      end

      it 'sets default options' do
        options = aws_ha_release.validate_options({ as_group_name: 'test_group' })
        expect(options[:elb_timeout]).not_to be_nil
        expect(options[:region]).not_to be_nil
        expect(options[:inservice_time_allowed]).not_to be_nil
        expect(options[:aws_access_key]).not_to be_nil
        expect(options[:aws_secret_key]).not_to be_nil
        expect(options[:min_inservice_time]).not_to be_nil
        expect(options[:num_simultaneous_instances]).not_to be_nil
        expect(options[:log_output]).not_to be_nil
        expect(options[:log_level]).not_to be_nil
      end
  
      context 'optional params' do
        it 'aws_access_key and aws_secret_key' do
          expect{
            aws_ha_release.validate_options({ as_group_name: 'test_group', aws_access_key: 'testkey' })
          }.to raise_error OptionParser::MissingArgument

          expect{
            aws_ha_release.validate_options({ as_group_name: 'test_group', aws_secret_key: 'testsecretkey' })
          }.to raise_error OptionParser::MissingArgument
  
          options = aws_ha_release.validate_options({ as_group_name: 'test_group', aws_access_key: 'testkey', aws_secret_key: 'testsecretkey' })
          expect(options[:aws_access_key]).to eq 'testkey'
          expect(options[:aws_secret_key]).to eq 'testsecretkey'
        end
      end
    end

    describe '#execute' do
      it 'calls CycleServers with valid options' do
        options = {
          region: 'us-east-1',
          elb_timeout: 60,
          inservice_time_allowed: 300,
          min_inservice_time: 30,
          num_simultaneous_instances: 1,
          log_output: 'log/test_group_cycling.log',
          log_level: 2,
          as_group_name: 'test_group',
          aws_access_key: 'testkey',
          aws_secret_key: 'secretkey'
        }
        cycle_servers = instance_double('CycleServers')

        expect(CycleServers).to receive(:new).with(options).and_return(cycle_servers)
        expect(cycle_servers).to receive(:cycle)

        AwsHaRelease.new(%w(--as-group-name test_group --aws_access_key testkey --aws_secret_key secretkey)).execute!
      end
    end
  end
end
