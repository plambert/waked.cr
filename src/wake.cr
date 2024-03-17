require "http/server"

module Wake
  VERSION           = "0.1.0"
  ETHERWAKE         = "/usr/bin/etherwake"
  MAC_ADDRESS_REGEX = Regex.new((["[0-9A-Fa-f][0-9A-Fa-f]"] * 6).join(":"), Regex::Options::IGNORE_CASE)

  # defaults
  DEFAULT_CONFIG_FILE    = ENV["WAKE_CONFIG"]? || "~/.config/waked/config.json"
  DEFAULT_LISTEN_PORT    = ENV["WAKE_PORT"]?.try(&.to_i) || 8111
  DEFAULT_LISTEN_ADDRESS = ENV["WAKE_LISTEN_ADDRESS"]? || "127.0.0.1"
  DEFAULT_INTERFACE      = ENV["WAKE_INTERFACE"]? || "enp9s0"
end
