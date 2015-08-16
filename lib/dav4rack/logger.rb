require 'logger'

module DAV4Rack
  # This is a simple wrapper for the Logger class. It allows easy access
  # to log messages from the library.
  class Logger
    LEVELS = %w(info debug warn fatal error).freeze

    class << self
      attr_writer :formatter

      def formatter
        @formatter ||= :default
      end

      # args:: Arguments for Logger -> [path, level] (level is optional) or a Logger instance
      # Set the path to the log file.
      def set(*args)
        if(LEVELS.all?{|meth| args.first.respond_to?(meth)})
          @@logger = args.first
        elsif(args.first.respond_to?(:to_s) && !args.first.to_s.empty?)
          @@logger = ::Logger.new(args.first.to_s, 'weekly')
        elsif(args.first)
          raise 'Invalid type specified for logger'
        end
        if(args.size > 1)
          @@logger.level = args[1]
        end
      end

      LEVELS.each do |lvl|
        define_method(lvl) do |*args|
          message, payload, _ = *args
          case formatter
          when :logfmt
            payload ||= {}
            payload[:msg] = message
            message = format_for_logfmt(lvl, payload)
          when :logstash
            payload ||= {}
            payload[:message] = message
            message = format_for_logstash(lvl, payload)
          end
          @@logger.send(lvl, message)
        end
      end

      private

      def format_for_logfmt(severity, payload)
        payload
      end

      def format_for_logstash(severity, message)
        data = message
        if data.is_a?(String) && data[0] == '{'
          data = (JSON.parse(message) rescue nil) || message
        end

        event = case data
                when LogStash::Event
                  data.clone
                when Hash
                  event_data = {
                    "@timestamp" => Time.now
                  }.merge(data)
                  LogStash::Event.new(event_data)
                when String
                  LogStash::Event.new("message" => data, "@timestamp" => Time.now)
                end

        event['severity'] ||= severity
        event.to_hash.to_json
      end
    end
  end
end
