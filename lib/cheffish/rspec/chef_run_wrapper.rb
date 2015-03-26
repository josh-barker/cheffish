require 'cheffish/basic_chef_client'

module Cheffish
  module RSpec
    class ChefRunWrapper
      def initialize(chef_config)
        @chef_config = chef_config || {}
      end

      attr_reader :chef_config

      class StringIOTee < StringIO
        def initialize(*streams)
          super()
          @streams = streams.flatten.select { |s| !s.nil? }
        end

        attr_reader :streams

        def write(*args, &block)
          super
          streams.each { |s| s.write(*args, &block) }
        end
      end

      def client
        @client ||= begin
          chef_config = self.chef_config.dup
          chef_config[:log_level] ||= :debug if !chef_config.has_key?(:log_level)
          chef_config[:verbose_logging] = false if !chef_config.has_key?(:verbose_logging)
          chef_config[:stdout] = StringIOTee.new(chef_config[:stdout])
          chef_config[:stderr] = StringIOTee.new(chef_config[:stderr])
          chef_config[:log_location] = StringIOTee.new(chef_config[:log_location])
          @client = ::Cheffish::BasicChefClient.new(nil,
            [ event_sink, Chef::Formatters.new(:doc, chef_config[:stdout], chef_config[:stderr]) ],
            chef_config
          )
        end
      end

      def event_sink
        @event_sink ||= EventSink.new
      end

      #
      # output
      #
      def stdout
        @client ? client.chef_config[:stdout].string : nil
      end
      def stderr
        @client ? client.chef_config[:stderr].string : nil
      end
      def logs
        @client ? client.chef_config[:log_location].string : nil
      end

      def resources
        client.resource_collection
      end

      def converge
        client.converge
      end

      def reset
        @client = nil
        @converged = nil
        @stdout = nil
        @stderr = nil
        @logs = nil
      end

      def converged?
        @converged
      end

      def updated?
        client.updated?
      end

      def up_to_date?
        !client.updated?
      end

      def output_for_failure_message
        message = ""
        if stdout && !stdout.empty?
          message << "---                    ---\n"
          message << "--- Chef Client Output ---\n"
          message << "---                    ---\n"
          message << stdout
          message << "\n" if !stdout.end_with?("\n")
        end
        if stderr && !stderr.empty?
          message << "---                          ---\n"
          message << "--- Chef Client Error Output ---\n"
          message << "---                          ---\n"
          message << stderr
          message << "\n" if !stderr.end_with?("\n")
        end
        if logs && !logs.empty?
          message << "---                  ---\n"
          message << "--- Chef Client Logs ---\n"
          message << "---                  ---\n"
          message << logs.string
        end
        message
      end

      class EventSink
        def initialize
          @events = []
        end

        attr_reader :events

        def method_missing(method, *args)
          @events << [ method, *args ]
        end
      end
    end
  end
end
