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
    @errors = []
    @batch_size = options[:batch_size].to_i
    @interval_time = options[:interval_time].to_i || 0
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
          check_title(response, location)
          check_description(response, location)
          check_url(location)
        else
          @errors << "The page is unreachable #{location}."
        end
      end
      sleep(@interval_time)
    end
  end

  def report
    @titles.each do |title, locations|
      if locations.size > 1
        @errors << "#{locations.slice(0, 5).join(', ')} #{'and ...' if locations.size > 5} have the same title '#{title}'."
      end
    end
    @descriptions.each do |description, locations|
      if locations.size > 1
        @errors << "#{locations.slice(0, 5).join(', ')} #{'and ...' if locations.size > 5} have the same description '#{description}'."
      end
    end
    puts @errors.join("\n")
  end

  private
    def get_response(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = "seo-checker"
      response = http.request(request)
    end

    def check_title(response, location)
      if response.body =~ %r{<title>(.*?)</title>}
        title = $1
      else
        @errors << "#{location} has no title."
      end
      (@titles[title] ||= []) << location
    end

    def check_description(response, location)
      if response.body =~ %r{<meta\s+name=["']description["']\s+content=["'](.*?)["']\s*/>|<meta\s+content=["'](.*?)["']\s+name=["']description["']\s*/>}
        description = $1 || $2
      else
        @errors << "#{location} has no description."
      end
      (@descriptions[description] ||= []) << location
    end

    def check_url(location)
      items = location.split('/')
      if items.find { |item| item =~ /^\d+$/ } || items.last =~ /^\d+\.htm(l)?/
        @errors << "#{location} should not just use ID number in URL."
      end
      if items.find { |item| item.split('-').size > 5 }
        @errors << "#{location} use excessive keywords"
      end
      if items.size > 8
        @errors << "#{location} has deep nesting of subdirectories"
      end
    end
end
