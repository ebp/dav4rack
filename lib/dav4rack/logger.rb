require 'logger'

module DAV4Rack
  # This is a simple wrapper for the Logger class. It allows easy access 
  # to log messages from the library.
  class Logger
    class << self
      attr_writer :formatter

      def formatter
        @formatter ||= :default
      end

      # args:: Arguments for Logger -> [path, level] (level is optional) or a Logger instance
      # Set the path to the log file.
      def set(*args)
        if(%w(info debug warn fatal).all?{|meth| args.first.respond_to?(meth)})
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
      
      def method_missing(method, message, payload = nil)
        if(defined? @@logger)
          if formatter == :logstash
            payload ||= {}
            payload[:message] = message
            event = format_for_logstash(method, payload)
            @@logger.send method, event.to_hash.to_json
          else
            @@logger.send method, message
          end
        end
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
                    "@tags"      => [],
                    "@timestamp" => Time.now
                  }.merge(event_data)
                  LogStash::Event.new(event_data)
                when String
                  LogStash::Event.new("message" => data, "@timestamp" => Time.now)
                end

        event['severity'] ||= severity
        event
      end
    end
  end
end
