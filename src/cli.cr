require "json"
require "./wake"
require "./server"

class Wake::CLI
  property arguments : Array(String)
  property configfile : String = DEFAULT_CONFIG_FILE
  property configpath : Path do
    Path[@configfile].expand(home: true)
  end
  property server : Wake::Server
  property listen_port : Int32 = DEFAULT_LISTEN_PORT
  property listen_host : String = DEFAULT_LISTEN_ADDRESS
  property interface : String
  property devices = {} of String => String

  # ameba:disable Metrics/CyclomaticComplexity
  def initialize(@arguments = ARGV)
    opts = @arguments.dup
    _port : Int32? = nil
    _host : String? = nil
    _iface : String? = nil
    while opt = opts.shift?
      case opt
      when "--port"
        _port = opts.shift?.try(&.to_i) || raise ArgumentError.new "#{opt}: expected an integer port number argument"
      when "--listen"
        _host = opts.shift? || raise ArgumentError.new "#{opt}: expected an ip address on which to listen"
      when "--interface"
        _iface = opts.shift? || raise ArgumentError.new "#{opt}: expected an interface name"
      when "--help"
        show_help
        exit 0
      when "--configfile", "--config"
        @configfile = opts.shift? || raise ArgumentError.new "#{opt}: expected a config file path"
      when %r{^(\w+)=(#{MAC_ADDRESS_REGEX})$}
        raise ArgumentError.new "#{opt}: #{$1} is already defined: #{@devices[$1]}" if @devices[$1]?
        @devices[$1] = $2
      else
        raise ArgumentError.new "#{opt}: unknown option"
      end
    end
    conf = read_config_file port: _port, host: _host, interface: _iface
    @listen_port = conf[:port].as(Int32) if conf[:port]?
    @listen_host = conf[:host].as(String) if conf[:host]?
    @interface = conf[:interface]?.as(String?) || raise ArgumentError.new "no interface given in config file or command argument"
    if 0 == devices.size
      raise ArgumentError.new "no devices defined in config file nor command parameters"
    end
    devices.each do |key, value|
      Log.info { "device #{key} at #{value}" }
    end
    @server = Wake::Server.new host: @listen_host, port: @listen_port, interface: @interface, devices: @devices
  end

  def run
    server.run
  end

  private def show_help
    STDOUT.print <<-HELP
      usage: #{PROGRAM_NAME} [options] <name=MAC address> ...

      options:
        --listen <address>          Address to listen to (default: #{DEFAULT_LISTEN_ADDRESS})
        --port <port>               Port number to listen to (default: #{DEFAULT_LISTEN_PORT})
        --interface <name>          Name of interface to use to send wake packet (default: #{DEFAULT_INTERFACE})
        --configfile <path>         Name of JSON config file to read
      HELP
  end

  # ameba:disable Metrics/CyclomaticComplexity
  private def read_config_file(port _port : Int32?, host _host : String?, interface _interface : String?)
    cfg = Hash(Symbol, String | Int32 | Hash(String, String)).new
    cfg[:port] = _port if _port
    cfg[:host] = _host if _host
    cfg[:interface] = _interface if _interface
    content = begin
      File.read configpath
    rescue e : File::NotFoundError
      Log.warn { "#{configpath}: file not found" }
    end
    return cfg unless content
    data = begin
      JSON.parse(content)
    rescue e : JSON::ParseException
      Log.warn { "#{configpath}: unable to parse JSON: #{e}" }
      exit 1
    end
    hash = data.as_h?
    unless hash
      Log.warn { "#{configpath}: expected a JSON object, found #{data.raw.class}" }
      exit 1
    end
    cfg[:interface] = hash["interface"].as_s if hash["interface"]?.try(&.as_s?)
    cfg[:host] = hash["host"].as_s if hash["host"]?.try(&.as_s?)
    if hash["port"]?
      cfg[:port] = hash["port"].as_i if hash["port"].as_i?
      cfg[:port] = (hash["port"].as_s.to_i? || raise ArgumentError.new "#{configpath}: invalid port: #{hash["port"]}") if hash["port"].as_s?
    end
    if hash["devices"]?
      if config_devices = hash["devices"].as_h?
        config_devices.each do |key, value|
          mac_addr = value.as_s? || raise ArgumentError.new "#{configpath}: devices: #{key}: expected a string, not a #{value.raw.class}"
          devices[key] ||= mac_addr
        end
      else
        raise ArgumentError.new "#{configpath}: devices: expected an object (string -> string)"
      end
    end
    cfg
  end
end

begin
  cli = Wake::CLI.new
  cli.run
rescue e : ArgumentError
  STDERR.puts "#{PROGRAM_NAME} [ERROR] #{e}"
  exit 1
end
