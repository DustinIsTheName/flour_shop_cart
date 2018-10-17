class ApiController < ApplicationController

  skip_before_filter :verify_authenticity_token
  before_filter :get_token

  def send_marketman
    # puts params

    market_man = MarketMan.first
    
    items = []
    transactions = []

    for item in params["line_items"]

      market_man_order = MarketManOrder.new

      market_man_order.name = item["title"]
      market_man_order.order_id = item["id"]
      market_man_order.price = item["price"]
      market_man_order.sku = item["sku"]
      market_man_order.quantity = item["quantity"]
      market_man_order.date_utc = Time.now.strftime('%Y/%m/%d %H:%M:%S')

      market_man_order.save

    end

    head :ok, content_type: "text/html"
  end


  private


    def get_token

      market_man = MarketMan.first
      
      unless market_man
        market_man = MarketMan.new
      end

      def create_token(market_man)
        url = URI('https://api.marketman.com/v2/buyers/auth/GetToken')
        api_credentials = {
          APIKey: ENV["MARKETMAN_API_KEY"], 
          APIPassword: ENV["MARKETMAN_API_PASSWORD"]
        }

        begin 

          token = marketman_http_request(url, '', api_credentials, 'post')

          market_man.auth_token = token["Token"]
          market_man.expiration = token["ExpireDateUTC"]

          if token["IsSuccess"]
            if market_man.save
              puts Colorize.green('created token')
            else
              puts Colorize.green('error creating token')
            end
          else
            puts token["ErrorMessage"]
          end

        rescue => e
          puts Colorize.orange('Error in marketman request')
          puts e
        end
      end

      if market_man.expiration
        if Time.parse(market_man.expiration) <= Time.now
          create_token market_man
        else
          puts Colorize.green('token valid')
        end
      else
        create_token market_man
      end

    end

    def marketman_http_request(url, token = nil, body = nil, type = nil)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      if type == "delete"
        request = Net::HTTP::Delete.new(url)
      elsif type == "post"
        request = Net::HTTP::Post.new(url)
      elsif type == "put"
        request = Net::HTTP::Put.new(url)
      elsif type == "get"
        request = Net::HTTP::Get.new(url)
      else
        request = Net::HTTP::Get.new(url)
      end

      if token
        request["AUTH_TOKEN"] = token
      end
      request["content-type"] = 'application/json'

      if body
        request.body = body.to_json
      end

      response = http.request(request)

      puts Colorize.yellow(request.body)
      puts Colorize.yellow(response.code)

      JSON.parse response.read_body
    end

end