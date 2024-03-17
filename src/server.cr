require "http/server"
require "./request-handler"

class Wake::Server
  property host : String
  property port : Int32
  property interface : String
  property prefix : String?
  property devices : Hash(String, String)
  property server

  def initialize(@host, @port, @interface, @prefix, @devices = {} of String => String)
    @server = HTTP::Server.new([
      HTTP::ErrorHandler.new,
      HTTP::LogHandler.new,
      Wake::RequestHandler.new(@devices, @interface, @prefix),
    ])
  end

  def run
    @server.bind_tcp @host, @port
    Log.info { "Listening on #{@host}:#{@port}" }
    @server.listen
  end
end
