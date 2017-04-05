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
    60
  end

  ### 記事収集処理
  BaseUrl = "http://www.keyakizaka46.com"
  BlogBaseUrl = "http://www.keyakizaka46.com/s/k46o/diary/member/list?ct="

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
    begin
      page = Nokogiri::HTML(open(url, 'User-Agent' => UserAgents.agent))

      page.css('article').each do |article|
        data = {}
        data[:title] = normalize article.css('.box-ttl > h3 > a').text
        data[:published] = normalize article.css('.box-bottom > ul > li')[0].text
        data[:published] = DateTime.parse(data[:published])

        data[:url] = BaseUrl + article.css('.box-bottom > ul > li')[1].css('a')[0][:href]
        data[:url] = normalize data[:url]

        image_url_list = Array.new()
        article.css('.box-article').css('img').each do |img|
          # http://cdn.keyakizaka46.com/images/14/12a/1059f8959c2e191c5cf15899f22be.jpg
          uri = URI.parse(img[:src])
          if uri.host != nil && uri.scheme != nil then
            image_url_list.push(img[:src])
          else
            image_url_list.push(BaseUrl + img[:src])
          end
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

  # 不要な改行を取り除く
  def normalize str
    url = str.gsub(/(\r\n|\r|\n|\f)/,"").strip
    url = url.gsub("http//www.keyakizaka46.com", "") if invalid? url
    url
  end

  # 不正なurlかどうか
  # 暫定
  def invalid? url
    begin
      u = URI.parse(url)
      u.host == "www.keyakizaka46.comhttp" || u.host== "cdn.keyakizaka46.comhttp"
    rescue URI::InvalidURIError => e
      true
    end
  end


=begin
  def url_normalize url
    # v1
    # [in]
    # http://www.keyakizaka46.com/mob/news/diarKijiShw.php?site=k46o&ima=0445&id=405&cd=member
    # [OUT]
    # http://www.keyakizaka46.com/mob/news/diarKijiShw.php?id=405&cd=member

    # v2
    # [in]
    # http://www.keyakizaka46.com/s/k46o/diary/detail/7358?ima=0000&cd=member
    uri = URI.parse(url)
    q_array = URI::decode_www_form(uri.query)
    q_hash = Hash[q_array]
    "http://www.keyakizaka46.com/mob/news/diarKijiShw.php?id=#{q_hash['id']}&cd=member"
  end
=end

  def save_data data, member
    puts "entrycrawler:save_data in"
    data[:member_id] = member['id']
    entry = Api::Entry.new
    data.each { |key, val|
      entry[key] = val
    }
    result = entry.save
    puts "entrycrawler:save_data out result->#{result}"
    yield(result, entry) if block_given?
  end

  def is_new? data
    Api::Entry.where('url = ?', data[:url]).first == nil
  end

  def routine_work
    puts "entrycrawler:routine_work in"
    Api::Member.all.order(key: :desc).each do |member|
      parse_for_key(member['key']) { |data|
        save_data(data, member) { |r, e|
          Push.new.push_entry e
        } if is_new? data
      }
    end
    puts "entrycrawler:routine_work out"
  end
end
