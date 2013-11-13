require 'dav4rack/logger'

module DAV4Rack
  
  class Handler
    include DAV4Rack::HTTPStatus    
    def initialize(options={})
      @options = options.dup
      unless(@options[:resource_class])
        require 'dav4rack/file_resource'
        @options[:resource_class] = FileResource
        @options[:root] ||= Dir.pwd
      end
      Logger.set(*@options[:log_to])
    end

    def call(env)
      begin
        start = Time.now
        request = Rack::Request.new(env)
        response = Rack::Response.new
        log_payload = {
          ip:         request.ip,
          method:     request.request_method,
          path:       request.path,
          controller: 'webdav',
          action:     (request.request_method || '').downcase
        }

        Logger.debug "Processing WebDAV request: #{request.path} (for #{request.ip} at #{Time.now}) [#{request.request_method}]"
        
        controller = nil
        begin
          controller = Controller.new(request, response, @options.dup)
          controller.authenticate
          res = controller.send(request.request_method.downcase)
          response.status = res.code if res.respond_to?(:code)
        rescue HTTPStatus::Unauthorized => status
          response.body = controller.resource.respond_to?(:authentication_error_msg) ? controller.resource.authentication_error_msg : 'Not Authorized'
          response['WWW-Authenticate'] = "Basic realm=\"#{controller.resource.respond_to?(:authentication_realm) ? controller.resource.authentication_realm : 'Locked content'}\""
          response.status = status.code
        rescue HTTPStatus::Status => status
          response.status = status.code
        end

        controller.append_info_to_payload(log_payload) if controller

        # Strings in Ruby 1.9 are no longer enumerable.  Rack still expects the response.body to be
        # enumerable, however.
        
        response['Content-Length'] = response.body.to_s.length unless response['Content-Length'] || !response.body.is_a?(String)
        response.body = [response.body] unless response.body.respond_to? :each
        response.status = response.status ? response.status.to_i : 200
        response.headers.keys.each{|k| response.headers[k] = response[k].to_s}
        
        # Apache wants the body dealt with, so just read it and junk it
        buf = true
        buf = request.body.read(8192) while buf

        Logger.debug "Response in string form. Outputting contents: \n#{response.body}" if response.body.is_a?(String)

        log_payload[:duration] = ((Time.now.to_f - start.to_f) * 1000).to_i
        log_payload[:status]   = response.status
        # [200] GET /dav/path (webdav#propfind)
        Logger.info "[#{response.status}] #{request.request_method} #{request.path} (#{log_payload[:controller]}##{log_payload[:action]})", log_payload
        
        response.body.is_a?(Rack::File) ? response.body.call(env) : response.finish
      rescue Exception => e
        log_payload[:duration] ||= ((Time.now.to_f - start.to_f) * 1000).to_i
        log_payload[:error] = ([e.message] + e.backtrace).join("; ")
        Logger.error "[#{request.ip}] #{request.request_method} #{request.path} - #{response.status} in #{log_payload[:duration]}ms - ERROR: #{log_payload[:error]}", log_payload
        raise e
      end
    end
    
  end

end
