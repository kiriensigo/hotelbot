require 'line/bot'
require 'net/http'
require 'uri'
require 'json'

class LineBotController < ApplicationController
  protect_from_forgery except: [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    Rails.logger.debug "Received body: #{body}"
    Rails.logger.debug "Signature: #{signature}"

    unless client.validate_signature(body, signature)
      Rails.logger.error "Invalid signature"
      return head :bad_request
    end

    events = client.parse_events_from(body)
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          begin
            message = search_and_create_message(event.message['text'])
            Rails.logger.debug "Created message: #{message.inspect}"
            response = client.reply_message(event['replyToken'], message)
            Rails.logger.debug "LINE API response: #{response.code} #{response.body}"
          rescue => e
            Rails.logger.error "Error sending LINE message: #{e.class} #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
          end
        end
      end
    end
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end
  end

  def search_and_create_message(keyword)
    Rails.logger.debug "Searching for keyword: #{keyword}"
    
    uri = URI.parse("https://app.rakuten.co.jp/services/api/Travel/KeywordHotelSearch/20170426")
    params = {
      format: 'json',
      keyword: keyword,
      applicationId: ENV['RAKUTEN_APPID'],
      hits: 5,
      responseType: 'small',
      datumType: 1,
      formatVersion: 2
    }
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)
    Rails.logger.debug "Rakuten API response: #{response.code} #{response.body}"

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body.force_encoding('UTF-8'))
      
      if result['hotels'].nil? || result['hotels'].empty?
        return {
          type: 'text',
          text: "申し訳ありませんが、「#{keyword}」に関する宿泊施設が見つかりませんでした。別のキーワードで試してみてください。"
        }
      else
        create_carousel_message(result['hotels'])
      end
    else
      Rails.logger.error "Rakuten API error: #{response.code} #{response.body}"
      {
        type: 'text',
        text: "申し訳ありませんが、検索中にエラーが発生しました。しばらくしてからもう一度お試しください。"
      }
    end
  end

  def create_carousel_message(hotels)
    bubbles = hotels.map do |hotel|
      hotel_info = hotel[0]['hotelBasicInfo']
      {
        type: 'bubble',
        hero: {
          type: 'image',
          url: hotel_info['hotelImageUrl'],
          size: 'full',
          aspectRatio: '20:13',
          aspectMode: 'cover'
        },
        body: {
          type: 'box',
          layout: 'vertical',
          contents: [
            {
              type: 'text',
              text: hotel_info['hotelName'],
              weight: 'bold',
              size: 'md',
              wrap: true
            },
            {
              type: 'box',
              layout: 'vertical',
              margin: 'lg',
              spacing: 'sm',
              contents: [
                {
                  type: 'box',
                  layout: 'baseline',
                  spacing: 'sm',
                  contents: [
                    {
                      type: 'text',
                      text: '住所',
                      color: '#aaaaaa',
                      size: 'sm',
                      flex: 1
                    },
                    {
                      type: 'text',
                      text: "#{hotel_info['address1']}#{hotel_info['address2']}",
                      wrap: true,
                      color: '#666666',
                      size: 'sm',
                      flex: 5
                    }
                  ]
                },
                {
                  type: 'box',
                  layout: 'baseline',
                  spacing: 'sm',
                  contents: [
                    {
                      type: 'text',
                      text: '料金',
                      color: '#aaaaaa',
                      size: 'sm',
                      flex: 1
                    },
                    {
                      type: 'text',
                      text: "#{hotel_info['hotelMinCharge']}円〜",
                      wrap: true,
                      color: '#666666',
                      size: 'sm',
                      flex: 5
                    }
                  ]
                }
              ]
            }
          ]
        },
        footer: {
          type: 'box',
          layout: 'vertical',
          spacing: 'sm',
          contents: [
            {
              type: 'button',
              style: 'link',
              height: 'sm',
              action: {
                type: 'uri',
                label: '詳細を見る',
                uri: hotel_info['hotelInformationUrl']
              }
            }
          ],
          flex: 0
        }
      }
    end

    {
      type: 'flex',
      altText: '宿泊施設の検索結果です',
      contents: {
        type: 'carousel',
        contents: bubbles
      }
    }
  end
end