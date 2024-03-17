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
      if mac_addr = @devices[$1]?
        output = IO::Memory.new
        error = IO::Memory.new
        status = Process.run command: "sudo", args: ["etherwake", "-i", @interface, "-D", mac_addr], chdir: "/", output: output, error: error
        if status.success?
          context.response.respond_with_status status: 200, message: output.to_s
        else
          context.response.respond_with_status status: 500, message: {output: output.to_s, error: error.to_s}.to_json
        end
      else
        context.response.respond_with_status status: 500, message: "#{context.request.path}: invalid device name"
      end
    else
      context.response.respond_with_status status: 500, message: "#{context.request.path}: invalid request path"
    end
  end
end
