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
          context.response.puts output.to_s
          context.response.puts error.to_s
          context.response.status = :ok
          context.response.status_message = "packet sent"
          # context.response.respond_with_status status: 200, message: "packet sent"
          # context.response.close
        else
          context.response.puts({output: output.to_s, error: error.to_s}.to_pretty_json)
          context.response.status = :server_error
          context.response.status_message = "etherwake failed"
          # context.response.respond_with_status status: 500, message: "etherwake failed"
          # context.response.close
        end
      else
        context.response.output.puts "#{context.request.path}: invalid device name"
        context.response.status = :server_error
        context.response.status_message = "invalid device"
        # context.response.respond_with_status status: 500, message: "invalid device"
        # context.response.close
      end
    else
      context.response.output.puts "#{context.request.path}: invalid request path"
      context.response.status = :server_error
      context.response.status_message = "invalid path"
      context.response.output.puts "invalid path: #{context.request.path.inspect}"
      # context.response.respond_with_status status: :server_error, message: "invalid path"
      # context.response.close
    end
  end
end
