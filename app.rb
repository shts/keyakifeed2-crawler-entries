require 'bundler'
require 'kconv'
Bundler.require # gemを一括require

require "date"
require "uri"

require_relative 'tables'
require_relative 'pusher'
require_relative 'useragent'
require_relative 'entrycrawler'
require_relative 'reportcrawler'
require_relative 'matomecrawler'

ec = EntryCrawler.new
rc = ReportCrawler.new
mc = MatomeCrawler.new

EM.run do
  EM::PeriodicTimer.new(ec.routine_time) do
    ec.routine_work
  end
  EM::PeriodicTimer.new(rc.routine_time) do
    rc.routine_work
  end
  EM::PeriodicTimer.new(mc.routine_time) do
    mc.routine_work
  end
end
