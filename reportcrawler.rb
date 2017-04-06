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

  def fetch_report target_url="http://www.keyakizaka46.com/s/k46o/diary/report/list?ima=0000"
    begin
      page = Nokogiri::HTML(open(target_url, 'User-Agent' => UserAgents.agent))
      page.css('.box-sub').each do |box|
        data = {}
        # uri
        data[:url] = "http://www.keyakizaka46.com" + box.css('a')[0][:href]

        # thumbnail
        data[:thumbnail_url] = box.css('.box-img').css('img')[0][:src]

        # title
        data[:title] = normalize box.css('.box-txt').css('.ttl').css('p').text

        # published
        pub = normalize box.css('.box-txt').css('time').text
        d = pub.split(".")
        data[:published] = DateTime.new(d[0].to_i, d[1].to_i, d[2].to_i)

        #image_url_list
        data[:image_url_list] = Array.new()
        article = Nokogiri::HTML(open(data[:url], 'User-Agent' => UserAgents.agent))
        article.css('.box-content').css('img').each do |img|
          data[:image_url_list].push img[:src]
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
    yield(report) if block_given?
  end

  def is_new? data
    Api::Report.where('url = ?', data[:url]).first == nil
  end

  def normalize str
    str.gsub(/(\r\n|\r|\n|\f)/,"").strip
  end

  def routine_work
    puts "reportcrawler:routine_work in"
    fetch_report { |data|
      save_data(data) { |report|
        Push.new.push_report report
      } if is_new? data
    }
    puts "reportcrawler:routine_work out"
  end

end
