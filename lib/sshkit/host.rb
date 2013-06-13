require 'etc'
require 'ostruct'

module SSHKit

  UnparsableHostStringError = Class.new(SSHKit::StandardError)

  class Host

    attr_accessor :password, :hostname, :port, :user

    def key=(new_key)
      @keys = [new_key]
    end

    def keys=(new_keys)
      @keys = new_keys
    end

    def keys
      Array(@keys)
    end

    def initialize(host_string_or_options_hash)

      unless host_string_or_options_hash.is_a?(Hash)
        suitable_parsers = [
          SimpleHostParser,
          HostWithPortParser,
          HostWithUsernameAndPortParser,
          IPv6HostWithPortParser,
          HostWithUsernameParser,
          HostWithUsernameAndPortParser
        ].select do |p|
          p.suitable?(host_string_or_options_hash)
        end

        if suitable_parsers.any?
          suitable_parsers.first.tap do |parser|
            @user, @hostname, @port = parser.new(host_string_or_options_hash).attributes
          end
        else
          raise UnparsableHostStringError, "Cannot parse host string #{host_string_or_options_hash}"
        end
      else
        host_string_or_options_hash.each do |key, value|
          if self.respond_to?("#{key}=")
            send("#{key}=", value)
          else
            raise ArgumentError, "Unknown host property #{key}"
          end
        end
      end
    end

    def hash
      user.hash ^ hostname.hash ^ port.hash
    end

    def username
      user
    end

    def eql?(other_host)
      other_host.hash == hash
    end
    alias :== :eql?
    alias :equal? :eql?

    def to_key
      to_s.to_sym
    end

    def to_s
      sprintf("%s@%s:%d", username, hostname, port)
    end

    def netssh_options
      {
        keys:     keys,
        port:     port,
        user:     user,
        password: password
      }
    end

    def properties
      @properties ||= OpenStruct.new
    end

  end

  # @private
  # :nodoc:
  class SimpleHostParser

    def self.suitable?(host_string)
      !host_string.match /[:|@]/
    end

    def initialize(host_string)
      @host_string = host_string
    end

    def username
      Etc.getlogin
    end

    def port
      22
    end

    def hostname
      @host_string
    end

    def attributes
      [username, hostname, port]
    end

  end

  # @private
  # :nodoc:
  class HostWithUsernameAndPortParser < SimpleHostParser

    def self.suitable?(host_string)
      !host_string.match /.*@.*\:.*/
    end

    def username
      @host_string.split('@').last.to_i
    end

    def port
      @host_string.split(':').last.to_i
    end

    def hostname
      @host_string.split(/@|\:/)[1]
    end

  end

  class HostWithPortParser < SimpleHostParser

    def self.suitable?(host_string)
      !host_string.match /[@|\[|\]]/
    end

    def port
      @host_string.split(':').last.to_i
    end

    def hostname
      @host_string.split(':').first
    end

  end

  # @private
  # :nodoc:
  class IPv6HostWithPortParser < SimpleHostParser

    def self.suitable?(host_string)
      host_string.match /[a-fA-F0-9:]+:\d+/
    end

    def port
      @host_string.split(':').last.to_i
    end

    def hostname
      @host_string.gsub!(/\[|\]/, '')
      @host_string.split(':')[0..-2].join(':')
    end

  end

  # @private
  # :nodoc:
  class HostWithUsernameParser < SimpleHostParser
    def self.suitable?(host_string)
      host_string.match(/@/) && !host_string.match(/\:/)
    end
    def username
      @host_string.split('@').first
    end
    def hostname
      @host_string.split('@').last
    end
  end

  # @private
  # :nodoc:
  class HostWithUsernameAndPortParser < SimpleHostParser
    def self.suitable?(host_string)
      host_string.match /@.*:\d+/
    end
    def username
      @host_string.split(/:|@/)[0]
    end
    def hostname
      @host_string.split(/:|@/)[1]
    end
    def port
      @host_string.split(/:|@/)[2].to_i
    end
  end

end
