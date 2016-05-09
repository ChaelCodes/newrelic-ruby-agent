# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require 'new_relic/agent/aws_info'

module NewRelic
  module Agent
    class UtilizationData
      METADATA_VERSION = 1

      def hostname
        NewRelic::Agent::Hostname.get
      end

      def container_id
        ::NewRelic::Agent::SystemInfo.docker_container_id
      end

      def cpu_count
        ::NewRelic::Agent::SystemInfo.clear_processor_info
        ::NewRelic::Agent::SystemInfo.num_logical_processors
      end

      def ram_in_mib
        ::NewRelic::Agent::SystemInfo.ram_in_mib
      end

      def to_collector_hash
        result = {
          :metadata_version => METADATA_VERSION,
          :logical_processors => cpu_count,
          :total_ram_mib => ram_in_mib,
          :hostname => hostname
        }

        append_aws_info(result)
        append_docker_info(result)
        append_configured_values(result)

        result
      end

      def append_aws_info(collector_hash)
        return unless Agent.config[:'utilization.detect_aws']

        aws_info = AWSInfo.new

        if aws_info.loaded?
          collector_hash[:vendors] ||= {}
          collector_hash[:vendors][:aws] = aws_info.to_collector_hash
        end
      end

      def append_docker_info(collector_hash)
        return unless Agent.config[:'utilization.detect_docker']

        if docker_container_id = container_id
          collector_hash[:vendors] ||= {}
          collector_hash[:vendors][:docker] = {:id => docker_container_id}
        end
      end

      def append_configured_values(collector_hash)
        collector_hash[:config] = config_hash unless config_hash.empty?
      end

      def config_hash
        config_hash = {}
        if valid_type?(:'utilization.billing_hostname')
          config_hash[:hostname] = Agent.config[:'utilization.billing_hostname']
        end
        if valid_type?(:'utilization.logical_processors')
          config_hash[:logical_processors] = Agent.config[:'utilization.logical_processors']
        end
        if valid_type?(:'utilization.total_ram_mib')
          config_hash[:total_ram_mib] = Agent.config[:'utilization.total_ram_mib']
        end
        config_hash
      end

      def valid_type?(key)
        if Agent.config[key].is_a?(Configuration::DEFAULTS[key][:type])
          return true
        elsif Agent.config[key]
          NewRelic::Agent.logger.warn "Configured #{key} should be a #{Configuration::DEFAULTS[key][:type]} but is a #{Agent.config[key].class} instead."
        end
        false
      end
    end
  end
end
