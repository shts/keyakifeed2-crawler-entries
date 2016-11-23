require 'bundler'
require 'kconv'
Bundler.require

require_relative 'tables'

class Push

  # GCMサーバの接続先 (https://android.googleapis.com/gcm/send)
  GCM_HOST = "fcm.googleapis.com"
  GCM_PATH = "/fcm/send"

  def push_entry e
    c = 0;
    while true do
      ids = Array.new

      fcms = Api::Fcm.limit(1000).offset(c * 1000).order(id: :desc)
      if fcms.count == 0 then
        puts "finish"
        break
      end

      fcms.each do |f|
        ids.push f['reg_id']
      end

      send_entry_message(ids, e)
      c = c + 1
    end
  end

  def push_report r
    c = 0;
    while true do
      ids = Array.new

      fcms = Api::Fcm.limit(1000).offset(c * 1000).order(id: :desc)
      if fcms.count == 0 then
        puts "finish"
        break
      end

      fcms.each do |f|
        ids.push f['reg_id']
      end

      send_report_message(ids, r)
      c = c + 1
    end
  end

  private
    # ブログ記事用
    def send_entry_message ids, e
      message = {
        "registration_ids" => ids,
        "collapse_key" => "collapse_key",
        "delay_while_idle" => false,
        "time_to_live" => 60,
        "data" => { "_object_key" => "object_entry",
                    "_id" => e['id'],
                    "_title" => e['title'],
                    "_url" => e['url'],
                    "_image_url_list" => e['image_url_list'],
                    "_member_id" => e['member_id'],
                    "_published" => e['published'],
                    "_member_name" => e.member['name_main'],
                    "_member_image_url" => e.member['image_url']
        }
      }
      post message, ids
    end

    # レポート用
    def send_report_message ids, r
      message = {
        "registration_ids" => ids,
        "collapse_key" => "collapse_key",
        "delay_while_idle" => false,
        "time_to_live" => 60,
        "data" => { "_object_key" => "object_report",
                    "_id" => r['id'],
                    "_title" => r['title'],
                    "_url" => r['url'],
                    "_published" => r['published'],
                    "_image_url_list" => r['image_url_list'],
                    "_created_at" => r['created_at'],
                    "_updated_at" => r['updated_at']
        }
      }
      post message, ids
    end

    def post message, ids
      # HTTPS POST実行
      http = Net::HTTP.new(GCM_HOST, 443);
      http.use_ssl = true
      http.start{ |w|
        response = w.post(GCM_PATH,
          message.to_json + "\n",
          {"Content-Type" => "application/json; charset=utf-8",
           "Authorization" => "key=#{ENV['PUSH_API_KEY']}"})
        #puts "response code = #{response.code}"
        #puts "response body = #{response.body}"
        hash = JSON.parse response.body
        ret = hash['results']
        ret.each_with_index { |r, i|
          # https://developers.google.com/cloud-messaging/http-server-ref
          # InternalServerError,Unavailable はリトライする
          if r.has_value?('InternalServerError') || r.has_value?('Unavailable') then
            # TODO: retry
            return
          end
          # 失敗時
          # {"error":"InvalidRegistration"}
          if r.has_key?('error') then
            if r.has_value?('MissingRegistration') || r.has_value?('InvalidRegistration') || r.has_value?('NotRegistered') then
              # 不要なキーは削除する
              puts "NG:delete -> #{ids[i]}"
              fcm = Api::Fcm.where(reg_id: ids[i]).first
              if fcm != nil then
                puts fcm.destroy
              end
            else
              puts "NG:unknown -> #{ids[i]}"
            end
          else
            # 成功時
            # {"message_id":"0:1479889709159316%d8e5392f6fbc52cd"}
            puts "OK -> #{ids[i]}"
          end
        }
      }
    end
end
