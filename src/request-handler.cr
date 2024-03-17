require "http/server/handler"
require "json"

class Wake::RequestHandler
  include HTTP::Handler
  property devices : Hash(String, String)
  property interface : String

  def initialize(@devices, @interface)
  end

  def call(context)
    if context.request.path =~ %r{^/(\w+)$}
      context.response.content_type = "text/plain"
      if mac_addr = @devices[$1]?
        output = IO::Memory.new
        error = IO::Memory.new
        status = Process.run command: "sudo", args: ["etherwake", "-i", @interface, "-D", mac_addr], chdir: "/", output: output, error: error
        if status.success?
          context.response.output << output.to_s
          context.response.output << '\n'
          context.response.respond_with_status status: 200, message: "packet sent"
          context.response.close
        else
          context.response.output << {output: output.to_s, error: error.to_s}.to_pretty_json
          context.response.output << '\n'
          context.response.respond_with_status status: 500, message: "etherwake failed"
          context.response.close
        end
      else
        context.response.output.puts "#{context.request.path}: invalid device name"
        context.response.respond_with_status status: 500, message: "invalid device"
        context.response.close
      end
    else
      context.response.output.puts "#{context.request.path}: invalid request path"
      context.response.respond_with_status status: 500, message: "invalid path"
      context.response.close
    end
  end
end
