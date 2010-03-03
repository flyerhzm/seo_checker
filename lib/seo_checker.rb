require 'enumerator'
require 'net/http'
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
  end

  def check
    begin
      check_sitemap
      check_location

      report
    rescue SEOException => e
      puts e.message
    end
  end

  def check_sitemap
    #TODO: allow manual sitemap file
    uri = URI.parse(@url)
    uri.path = '/sitemap.xml'
    response = get_response(uri)
    if response.is_a? Net::HTTPSuccess
      @locations = response.body.scan(%r{<loc>(.*?)</loc>}).flatten
    else
      raise SEOException, "Error: There is no sitemap.xml."
    end
  end

  def check_location
    @batch_size ||= @locations.size
    @locations.each_slice(@batch_size) do |batch_locations|
      batch_locations.each do |location|
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
      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = "seo-checker"
      response = http.request(request)
    end

    def check_title(header_string, location)
      if header_string =~ %r{<title>(.*?)</title>}
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
      unless @unreachables.empty?
        print "#{@unreachables.slice(0, 5).join(",\n")} #{'and ...' if @unreachables.size > 5} are unreachable.\n\n"
      end
      unless @no_titles.empty?
        print "#{@no_titles.slice(0, 5).join(",\n")} #{'and ...' if @no_titles.size > 5} have no title.\n\n"
      end
      unless @no_descriptions.empty?
        print "#{@no_descriptions.slice(0, 5).join(",\n")} #{'and ...' if @no_descriptions.size > 5} have no description.\n\n"
      end
      @titles.each do |title, locations|
        if locations.size > 1
          print "#{locations.slice(0, 5).join(",\n")} #{'and ...' if locations.size > 5} have the same title '#{title}'.\n\n"
        end
      end
      @descriptions.each do |description, locations|
        if locations.size > 1
          print "#{locations.slice(0, 5).join(",\n")} #{'and ...' if locations.size > 5} have the same description '#{description}'.\n\n"
        end
      end
      unless @id_urls.empty?
        print "#{@id_urls.values.slice(0, 5).join(",\n")} #{'and ...' if @id_urls.values.size > 5} use ID number in URL.\n\n"
      end
      unless @excessive_keywords.empty?
        print "#{@excessive_keywords.slice(0, 5).join(",\n")} #{'and ...' if @excessive_keywords.size > 5} use excessive keywords in URL.\n\n"
      end
      unless @nesting_subdirectories.empty?
        print "#{@nesting_subdirectories.slice(0, 5).join(",\n")} #{'and ...' if @nesting_subdirectories.size > 5} have deep nesting of subdirectories in URL.\n\n"
      end
    end
end
