require 'enumerator'
require 'logger'
require 'zlib'
require 'stringio'
require 'net/http'
require 'net/https'
require 'uri'

class SEOException < Exception
end

class SEOChecker
  def initialize(url, options={})
    @url = url
    @locations = []
    @titles = {}
    @descriptions = {}
    @id_urls = {}
    @excessive_keywords = []
    @nesting_subdirectories = []
    @no_titles = []
    @no_descriptions = []
    @unreachables = []
    @batch_size = options[:batch_size] ? options[:batch_size].to_i : nil
    @interval_time = options[:interval_time].to_i
    @logger = options[:logger] == true ? Logger.new(STDOUT) : options[:logger]
  end

  def check
    begin
      check_robot
      check_sitemap("#{@url}/sitemap.xml") if @locations.empty?
      check_sitemap("#{@url}/sitemap.xml.gz") if @locations.empty?
      raise SEOException, "Error: There is no sitemap.xml or sitemap.xml.gz" if @locations.empty?

      check_location

      report
    rescue SEOException => e
      puts e.message
    end
  end

  def check_robot
    uri = URI.parse(@url)
    uri.path = '/robots.txt'
    response = get_response(uri)
    if response.is_a? Net::HTTPSuccess and response.body =~ /Sitemap:\s*(.*)/
      check_sitemap($1)
    end
  end

  def check_sitemap(url)
    @logger.debug "checking #{url} file" if @logger
    uri = URI.parse(url)
    response = get_response(uri)
    if response.is_a? Net::HTTPSuccess
      body = url =~ /gz$/ ? Zlib::GzipReader.new(StringIO.new(response.body)).read : response.body
      if body.index "<sitemap>"
        sitemap_locs = body.scan(%r{<loc>(.*?)</loc>}).flatten
        sitemap_locs.each { |loc| check_sitemap(loc) }
      else
        @locations = body.scan(%r{<loc>(.*?)</loc>}).flatten
      end
    end
  end

  def check_location
    @batch_size ||= @locations.size
    @locations.each_slice(@batch_size) do |batch_locations|
      batch_locations.each do |location|
        @logger.debug "checking #{location}" if @logger
        response = get_response(URI.parse(location))
        if response.is_a? Net::HTTPSuccess
          if response.body =~ %r{<head>(.*?)</head>}m
            check_title($1, location)
            check_description($1, location)
          else
            @no_titles << location
            @no_descriptions << location
          end
          check_url(location)
        else
          @unreachables << location
        end
      end
      sleep(@interval_time)
    end
  end

  private
    def get_response(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = "seo-checker"
      response = http.request(request)
    end

    def check_title(header_string, location)
      if header_string =~ %r{<title>(.*?)</title>} && $1 != ''
        title = $1
        (@titles[title] ||= []) << location
      else
        @no_titles << location
      end
    end

    def check_description(header_string, location)
      if header_string =~ %r{<meta\s+name=["']description["']\s+content=["'](.*?)["']\s*/>|<meta\s+content=["'](.*?)["']\s+name=["']description["']\s*/>}
        description = $1 || $2
        (@descriptions[description] ||= []) << location
      else
        @no_descriptions << location
      end
    end

    def check_url(location)
      items = location.split('/')
      if items.find { |item| item =~ /^\d+$/ } || items.last =~ /^\d+\.htm(l)?/
        @id_urls[location.gsub(%r{/\d+/}, 'id')] = location
      end
      if items.find { |item| item.split('-').size > 5 }
        @excessive_keywords << location
      end
      if items.size > 8
        @nesting_subdirectories << location
      end
    end

    def report
      report_non_empty(@unreachables, "are unreachable.")
      report_non_empty(@no_titles, "have no title.")
      report_non_empty(@no_descriptions, "have no description.")
      report_same(@titles, 'title')
      report_same(@descriptions, 'description')
      report_non_empty(@id_urls.values, "use ID number in URL.")
      report_non_empty(@excessive_keywords, "use excessive keywords in URL.")
      report_non_empty(@nesting_subdirectories, "have deep nesting of subdirectories in URL.")
    end

    def report_same(variables, name)
      variables.each do |variable, locations|
        if locations.size > 1
          print "#{locations.slice(0, 5).join(",\n")} #{'and ...' if locations.size > 5} have the same #{name} '#{variable}'.\n\n"
        end
      end
    end

    def report_non_empty(variables, suffix)
      unless variables.empty?
        print "#{variables.slice(0, 5).join(",\n")} #{'and ...' if variables.size > 5} #{suffix}\n\n"
      end
    end
end
