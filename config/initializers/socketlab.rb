# overriding because UIUC uses a different endpoint than is hard-coded in the gem

module SocketLabs
  module InjectionApi
    class SocketLabsClient
      def initialize (
        server_id,
        api_key,
        proxy= {}
      )
        @server_id = server_id
        @api_key = api_key
        @proxy = proxy
        @endpoint = "https://inject-cx.socketlabs.com/api/v1/email"
        @request_timeout = 120
        @number_of_retries = 0
      end
    end
  end
end
