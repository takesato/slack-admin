require 'slack/admin/version'
require 'httmultiparty'
require 'faye/websocket'
require 'eventmachine'
require 'open-uri'
require 'tempfile'
require 'yaml'
require 'uri'

module Slack
  module Admin
    class Client
      include HTTMultiParty

      base_uri 'https://slack.com/api'

      attr_accessor :emoji_list

      def initialize(token)
        @initialize_time = Time.now.to_i
        @token = token
        @url = self.class.post('/rtm.start', body: {token: @token})['url']
        @callbacks ||= {}
      end

      def start
        EM.run do
          ws = Faye::WebSocket::Client.new(@url)

          ws.on :open do |event|
            @emoji_list = self.class.post('/emoji.list', body: {token: @token})['emoji'].keys
          end

          ws.on :message do |event|
            data = JSON.parse(event.data)
            if data['type'] == 'emoji_changed'
              check_added_emoji
            end
          end

          ws.on :close do |event|
            EM.stop
          end
        end
      end

      def check_added_emoji
        new_emoji_list = self.class.post('/emoji.list', body: {token: @token})['emoji'].keys
        diff = new_emoji_list - @emoji_list
        if !diff.empty?
          diff.each do|emoji|
            post_message('C09Q0ELLQ', "絵文字 :#{emoji}: #{emoji} が追加されました" )
          end
        end
        diff = @emoji_list - new_emoji_list 
        if !diff.empty?
          diff.each do|emoji|
            post_message('C09Q0ELLQ', "絵文字 :#{emoji}: が削除されました" )
          end
        end
        @emoji_list = new_emoji_list
      end

      def post_message(channel, message)
        message = {
          token: @token,
          username: 'Slack Admin',
          channel: channel,
          text: message
        }
        self.class.post('/chat.postMessage', body: message)
      end
      def output(time, channel, user, message)
        $stdout.puts "#{time} #{channel} #{user}  #{message}"
      end
    end
  end
end
