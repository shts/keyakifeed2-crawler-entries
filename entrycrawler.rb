require 'bundler'
require 'kconv'
Bundler.require # gemを一括require

require "date"
require "uri"

require_relative 'tables'
require_relative 'pusher'
require_relative 'useragent'

class EntryCrawler

  def routine_time
    35
  end

  ### 記事収集処理
  BaseUrl = "http://www.keyakizaka46.com"
  BlogBaseUrl = "http://www.keyakizaka46.com/mob/news/diarKiji.php?cd=member&ct="

  def parse_for_key key
    return if key == nil
    parsepage(BlogBaseUrl + key, false) { |data|
      yield(data) if block_given?
    }
  end

  def parse url
    parsepage(url) { |data|
      yield(data) if block_given?
    }
  end

  # 1記事から情報を取得する
  def parsepage url, loop=true
    puts "parsepage in : #{url}"
    begin
      page = Nokogiri::HTML(open(url, 'User-Agent' => UserAgents.agent))

      page.css('article').each do |article|

        data = {}
        data[:title] = normalize article.css('.box-ttl > h3').text
        data[:published] = normalize article.css('.box-bottom > ul > li')[0].text
        data[:published] = DateTime.parse(data[:published])

        data[:url] = BaseUrl + article.css('.box-bottom > ul > li')[1].css('a')[0][:href]
        data[:url] = url_normalize data[:url]

        image_url_list = Array.new()
        article.css('.box-article').css('img').each do |img|
          image_url_list.push(BaseUrl + img[:src])
        end
        data[:image_url_list] = image_url_list

        yield(data) if block_given?
      end

      return if !loop

      page.css('.pager > ul > li').each do |li|
        puts "no more page" if li.text == '>'
        parse(BaseUrl + li.css('a')[0][:href]) { |data|
          yield(data) if block_given?
        } if li.text == '>'
      end
    rescue OpenURI::HTTPError => ex
      puts "******************************************************************************************"
      puts "HTTPError : url(#{url}) retry!!!"
      puts "******************************************************************************************"
      sleep 5
      retry
    end
  end

  def normalize str
    str.gsub(/(\r\n|\r|\n|\f)/,"").strip
  end

  def url_normalize url
    # before
    # http://www.keyakizaka46.com/mob/news/diarKijiShw.php?site=k46o&ima=0445&id=405&cd=member
    # after
    # http://www.keyakizaka46.com/mob/news/diarKijiShw.php?id=405&cd=member
    uri = URI.parse(url)
    q_array = URI::decode_www_form(uri.query)
    q_hash = Hash[q_array]
    "http://www.keyakizaka46.com/mob/news/diarKijiShw.php?id=#{q_hash['id']}&cd=member"
  end

  def save_data data, member
    data[:member_id] = member['id']
    entry = Api::Entry.new
    data.each { |key, val|
      entry[key] = val
    }
    result = entry.save
    yield(result, entry) if block_given?
  end

  def is_new? data
    Api::Entry.where('url = ?', data[:url]).first == nil
  end

  def routine_work
    Api::Member.all.order(key: :desc).each do |member|
      parse_for_key(member['key']) { |data|
        save_data(data, member) { |r, e|
          Push.new.push_entry e
        } if is_new? data
      }
    end
  end
end
