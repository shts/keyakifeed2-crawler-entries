require 'sinatra/activerecord'
require 'sinatra/activerecord/rake'

if File.exist?("database.yml")
  #Local
  ActiveRecord::Base.configurations = YAML.load_file('database.yml')
  ActiveRecord::Base.establish_connection(:development)
else
  #Heroku
  ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])
end
