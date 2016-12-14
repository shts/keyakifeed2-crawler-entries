if File.exist?("database.yml")
  #Local
  ActiveRecord::Base.configurations = YAML.load_file('database.yml')
  ActiveRecord::Base.establish_connection(:development)
else
  #Heroku
  ActiveRecord::Base.establish_connection(ENV['HEROKU_POSTGRESQL_AQUA_URL'])
end

module Api
  # DBの設定
  class Member < ActiveRecord::Base
    has_many :entries

    before_save :prepare_save

    def prepare_save
      self.favorite = 0 if self.favorite == nil || self.favorite < 0
      self
    end

    def favinc
      self.favorite = self.favorite + 1
    end

    def favdec
      self.favorite = self.favorite - 1
    end

  end

  class Entry < ActiveRecord::Base
    belongs_to :member
  end

  class Report < ActiveRecord::Base
  end

  class Matome < ActiveRecord::Base
  end

  class Fcm < ActiveRecord::Base
  end
end
