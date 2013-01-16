begin
  require 'net/https'
rescue LoadError
  warn "Warning: no such file to load -- net/https. Make sure openssl is installed if you want ssl support"
  require 'net/http'
end
require 'zlib'
require 'addressable/uri'

module OAuth2
  class HTTPConnection

    NET_HTTP_EXCEPTIONS = [
      EOFError,
      Errno::ECONNABORTED,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EINVAL,
      Net::HTTPBadResponse,
      Net::HTTPHeaderSyntaxError,
      Net::ProtocolError,
      SocketError,
      Zlib::GzipFile::Error,
    ]

    attr_accessor :config, :scheme, :host, :port, :max_redirects, :ssl,
                  :user_agent, :accept, :max_redirects

    def self.default_options
      {
        :headers => {
          'Accept'     => 'application/json',
          'User-Agent' => "OAuth2 Ruby Gem #{OAuth2::Version}"
        },
        :ssl => {:verify => true},
        :max_redirects => 5
      }
    end

    def initialize(url, options={})
      @uri = Addressable::URI.parse(url)
      self.class.default_options.keys.each do |key|
        instance_variable_set(:"@#{key}", options.fetch(key,  self.class.default_options[key]))
      end
    end

    def default_headers
      self.class.default_options[:headers]
    end

    def scheme=(scheme)
      unless ['http', 'https'].include? scheme
        raise "The scheme #{scheme} is not supported. Only http and https are supported"
      end
      @scheme = scheme
    end

    def scheme
      @scheme ||= @uri.scheme
    end

    def host
      @host ||= @uri.host
    end

    def port
      @port ||= (@uri.port || 80)
    end

    def absolute_url(path='')
      "#{scheme}://#{host}#{path}"
    end

    def ssl?(newscheme)
      (newscheme) == "https" ? true : false
    end

    def ssl=(opts)
      raise "Expected Hash but got #{opts.class.name}" unless opts.is_a?(Hash)
      @ssl.merge!(opts)
    end

    def http_connection(opts={})
      _host   = opts[:host]   || host
      _port   = opts[:port]   || port
      _scheme = opts[:scheme] || scheme

      @http_client = Net::HTTP.new(_host, _port)

      configure_ssl(@http_client) if ssl?(_scheme)

      @http_client
    end

    def request(method, path, opts={})
      headers         = default_headers.merge(opts.fetch(:headers, {}))
      params          = opts[:params] || {}
      query           = Addressable::URI.form_encode(params)
      method          = method.to_s.downcase
      normalized_path = query.empty? ? path : [path, query].join("?")
      client          = http_connection(opts.fetch(:connection_options, {}))

      if (method == 'post' || method == 'put')
        headers['Content-Type'] ||= 'application/x-www-form-urlencoded'
      end

      case method
      when 'get'
        response = client.get(normalized_path, headers)
      when 'post'
        response = client.post(path, query, headers)
      when 'put'
        response = client.put(path, query, headers)
      when 'delete'
        response = client.delete(normalized_path, headers)
      else
        raise "Unsupported HTTP method, #{method.inspect}"
      end

      status = response.code.to_i

      case status
      when 301, 302, 303, 307
        unless redirect_limit_reached?
          if status == 303
            method = :get
            params = nil
          end
          redirect_uri = Addressable::URI.parse(response.header['Location'])
          conn = {
            :scheme => redirect_uri.scheme,
            :host   => redirect_uri.host,
            :port   => redirect_uri.port
          }
          return request(method, redirect_uri.path, :params => params, :headers => headers, :connection_options => conn)
        end
      when 200..599
        @redirect_count = 0
      else
        raise "Unhandled status code value of #{response.code}"
      end
      response
    rescue *NET_HTTP_EXCEPTIONS
      raise "Error::ConnectionFailed, $!"
    end

  private

    def configure_ssl(http)
      http.use_ssl      = true
      http.verify_mode  = ssl_verify_mode
      http.cert_store   = ssl_cert_store

      http.cert         = ssl[:client_cert]  if ssl[:client_cert]
      http.key          = ssl[:client_key]   if ssl[:client_key]
      http.ca_file      = ssl[:ca_file]      if ssl[:ca_file]
      http.ca_path      = ssl[:ca_path]      if ssl[:ca_path]
      http.verify_depth = ssl[:verify_depth] if ssl[:verify_depth]
      http.ssl_version  = ssl[:version]      if ssl[:version]
    end

    def ssl_verify_mode
      if ssl.fetch(:verify, true)
          OpenSSL::SSL::VERIFY_PEER
      else
          OpenSSL::SSL::VERIFY_NONE
      end
    end

    def ssl_cert_store
      return ssl[:cert_store] if ssl[:cert_store]
      cert_store = OpenSSL::X509::Store.new
      cert_store.set_default_paths
      cert_store
    end

    def redirect_limit_reached?
      @redirect_count ||= 0
      @redirect_count += 1
      @redirect_count > @max_redirects
    end
  end
end
