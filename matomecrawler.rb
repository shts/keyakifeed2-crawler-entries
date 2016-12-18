require 'bundler'
require 'kconv'
Bundler.require # gemを一括require

require "date"
require "uri"

require_relative 'tables'
require_relative 'useragent'

# Doc
# http://feedjira.com/
# https://github.com/feedjira/feedjira
# http://stackoverflow.com/questions/2481285/ruby-feedzirra-and-updates/2487826#2487826
# http://xoyip.hatenablog.com/entry/2014/01/20/201703
# http://ruby-doc.org/stdlib-2.2.3/libdoc/rss/rdoc/RSS.html

# Source
# Entry Object
# https://github.com/feedjira/feedjira/blob/master/lib/feedjira/parser/rss_entry.rb

# Sample
# https://binarapps.com/blog/feedjira-with-rails/
# http://raspygold.com/ruby-rss-atom-feed-parsing/

require "feedbag"
require "feedjira"

require_relative "app"
require_relative 'useragent'

class MatomeCrawler

  def routine_time
    45
  end

  url_list = [
    "http://keyakizaka46ch.jp",
    "http://keyakizaka1.blog.jp",
    "http://keyakizakamatome.blog.jp",
    "http://keyaki46.2chblog.jp",
    "http://torizaka46.2chblog.jp",
    "http://keyakizaka46torimatome.com",
    "http://www.keyakizaka46matomerabo.com"
  ]

  def normalize str
    str.gsub(/(\r\n|\r|\n|\f)/,"").strip
  end

  def is_new? entry_url
    Api::Matome.where('entry_url = ?', entry_url).first == nil
  end

  def routine_work
    url_list.each do |site_url|
      feed_urls = Feedbag.find site_url
      feed = Feedjira::Feed.fetch_and_parse feed_urls.first

      feed.entries.each do |entry|
        if is_new? entry.url then
          matome = Api::Matome.new
          matome[:feed_title] = feed.title
          matome[:feed_url] = feed.url
          matome[:entry_title] = entry.title
          matome[:entry_url] = entry.url
          matome[:entry_published] = entry.published
          matome[:entry_categories] = entry.categories
          matome.save
        else
          puts "already saved url -> #{entry.url}"
        end
      end
    end
  end

end
