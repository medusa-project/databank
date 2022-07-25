require "net/http"
require "uri"
require 'json'

class CheckToken

  def initialize(app)
    @app = app
  end

  def call(env)

    begin

      if token_ok(env)
        @app.call(env)
      else
        [401, {'Content-Type' => 'text/html', 'WWW-Authenticate' => 'Token token=[TOKEN FROM ILLINOIS DATA BANK]'}, [env.to_yaml]]
      end

    rescue Exception => ex
      # ..|..
      return [500, {"Content-Type" => "text/html"}, [ex.message]]
    end

  end

  def token_ok(env)

    begin

      if env.has_key?('HTTP_REFERER') && env.has_key?('HTTP_HOST')
        referer = env['HTTP_REFERER']
        referer_parts = referer.split('/')
        if referer_parts[2] == env['HTTP_HOST']
          # return true right away if request comes from this instance of Illinois Data Bank
          return true
        end
      elsif env.has_key?('HTTP_AUTHORIZATION')

        auth_body = env['HTTP_AUTHORIZATION']

        auth_parts = auth_body.split("token=")

        token = auth_parts[1]

        uri = URI.parse("http://localhost:3000/check_token?token=#{token}")

        response = Net::HTTP.get_response(uri)

        body_json = JSON.parse(response.body)

        return body_json['isValid']

      else
        return false
      end

    rescue Exception => ex
      # ..|..
      return false
    end
  end

end