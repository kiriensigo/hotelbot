class LineBotController < ApplicationController
    require 'httpclient'
    require 'line/bot'
    protect_from_forgery except: [:callback]
  
    def callback
        body = request.body.read
        signature = request.env['HTTP_X_LINE_SIGNATURE']
        unless client.validate_signature(body, signature)
          return head :bad_request
        end
      
        events = client.parse_events_from(body)
        events.each do |event|
          case event
          when Line::Bot::Event::Message
            case event.type
            when Line::Bot::Event::MessageType::Text
              message = search_and_create_message(event.message['text'])
              client.reply_message(event['replyToken'], message)
            end
          end
        end
        head :ok
      end
  
    private
  
    def client
            @client ||= Line::Bot::Client.new { |config|
              config.channel_secret = ENV['LINE_CHANNEL_SECRET']
              config.channel_token = ENV['LINE_CHANNEL_TOKEN']
            }
    end

    def search_and_create_message(keyword)
      Rails.logger.debug "Received keyword: #{keyword}"
      
      http_client = HTTPClient.new
      url = 'https://app.rakuten.co.jp/services/api/Travel/KeywordHotelSearch/20170426'
      query = {
       'keyword' => keyword,
        'applicationId' => ENV['RAKUTEN_APPID'],
        'hits' => 5,
        'responseType' => 'small',
        'formatVersion' => 2
      }
      # Rails.logger.debug "RAKUTEN_APPID: #{ENV['RAKUTEN_APPID']}"
      # Rails.logger.debug "Full URL: #{url}?#{query.to_query}"
      
      begin
        response = http_client.get(url, query)
        
         Rails.logger.debug "Rakuten API response status: #{response.status}"
         Rails.logger.debug "Rakuten API response body: #{response.body}"
        
        if response.status == 200
          result = JSON.parse(response.body)
          
          text = ''
          if result['hotels'] && !result['hotels'].empty?
            result['hotels'].each do |hotel|
              text += hotel[0]['hotelBasicInfo']['hotelName'] + "\n" +
                      hotel[0]['hotelBasicInfo']['hotelInformationUrl'] + "\n\n"
            end
          else
            text = "該当するホテルが見つかりませんでした。"
          end
        else
          error_body = JSON.parse(response.body) rescue nil
          error_message = error_body['error_description'] if error_body
          text = "申し訳ありません。ホテル情報の取得中にエラーが発生しました。(#{error_message || "ステータスコード: #{response.status}"})"
        end
      rescue => e
        Rails.logger.error "test: #{e.message}"
        text = "申し訳ありません。ホテル情報の取得中にエラーが発生しました。"
      end
    
      message = {
        type: 'text',
        text: text
      }
      
      # Rails.logger.debug "Created message: #{message.inspect}"
      
      message
    end
  end