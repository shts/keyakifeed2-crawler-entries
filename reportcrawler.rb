require 'bundler'
require 'kconv'
Bundler.require # gemを一括require

require "date"
require "uri"

require_relative 'tables'
require_relative 'pusher'
require_relative 'useragent'

class ReportCrawler

  def routine_time
    60 * 30
  end

  BaseReportUrl = "http://www.keyakizaka46.com/mob/news/diarShw.php?cd=report"
  # http://www.keyakizaka46.com/mob/news/diarShw.php?cd=report
  # http://www.keyakizaka46.com/mob/news/diarKijiShw.php?cd=report

  def fetch_report
    begin
      page = Nokogiri::HTML(open(BaseReportUrl, 'User-Agent' => UserAgents.agent))
      page.css('.box-sub').each do |box|
        data = {}
        # uri
        #puts url_normalize "#{box.css('a')[0][:href]}"
        # /mob/news/diarKijiShw.php?site=k46o&ima=5839&id=2539&cd=report
        # "http://www.keyakizaka46.com" + box.css('a')[0][:href]
        data[:url] = url_normalize box.css('a')[0][:href]

        # thumbnail
        # puts thumbnail_url_normalize "#{box.css('.box-img').css('img')[0][:src]}"
        # thumbnail_url_normalize box.css('.box-img').css('img')[0][:src]
        data[:thumbnail_url] = thumbnail_url_normalize box.css('.box-img').css('img')[0][:src]

        # title
        # puts normalize "#{box.css('.box-txt').css('.ttl').css('p').text}"
        data[:title] = normalize box.css('.box-txt').css('.ttl').css('p').text

        # published
        # puts normalize "#{box.css('.box-txt').css('time').text}"
        pub = normalize box.css('.box-txt').css('time').text
        d = pub.split(".")
        data[:published] = DateTime.new(d[0].to_i, d[1].to_i, d[2].to_i)

        #image_url_list
        data[:image_url_list] = Array.new()
        article = Nokogiri::HTML(open(data[:url], 'User-Agent' => UserAgents.agent))
        article.css('.box-content').css('img').each do |img|
          image_url = thumbnail_url_normalize img[:src]
          data[:image_url_list].push image_url
        end

        yield(data) if block_given?
      end
    rescue OpenURI::HTTPError => ex
      puts "******************************************************************************************"
      puts "HTTPError : url(#{ex.message}) retry!!!"
      puts "******************************************************************************************"
      if ex.message != "404 Not Found" then
        sleep 5
        retry
      end
    end
  end

  def save_data data
    report = Api::Report.new
    data.each { |key, val|
      report[key] = val
    }
    result = report.save
    yield(result, report) if block_given?
  end

  def is_new? data
    Api::Report.where('url = ?', data[:url]).first == nil
  end

  def normalize str
    str.gsub(/(\r\n|\r|\n|\f)/,"").strip
  end

  def thumbnail_url_normalize url
    uri = Addressable::URI.parse(url)
    if uri.scheme == nil || uri.host == nil then
      "http://www.keyakizaka46.com" + url
    else
      url
    end
  end

  def url_normalize url
    # before
    # http://www.keyakizaka46.com/mob/news/diarKijiShw.php?site=k46o&ima=1900&id=1820&cd=report
    # after
    # http://www.keyakizaka46.com/mob/news/diarKijiShw.php?id=1820&cd=report
    uri = URI.parse(url)
    q_array = URI::decode_www_form(uri.query)
    q_hash = Hash[q_array]
    "http://www.keyakizaka46.com/mob/news/diarKijiShw.php?id=#{q_hash['id']}&cd=report"
  end

  def routine_work
    puts "reportcrawler:routine_work in"
    fetch_report { |data|
      save_data(data) { |result, report|
        Push.new.push_report report
      } if is_new? data
    }
    puts "reportcrawler:routine_work out"
  end

end
