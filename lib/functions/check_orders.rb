class CheckOrders

	def self.fulfill(number_of_days)
		number_of_days = number_of_days.to_i
		pages = (ShopifyAPI::Order.count/250.0).ceil

		for page in 1..pages
			orders = ShopifyAPI::Order.find(:all, params: {limit: 250, page: page})
			date_now = DateTime.now
			date_now = (date_now + number_of_days.days).strftime('%Y/%m/%d')

			for order in orders
				if order.tags.split(', ').include? 'fulfilled'
          order_date = order.note_attributes&.select{|a| a.name == 'Pickup-Date'}&.first&.value

          unless order_date
            order_date = order.note_attributes&.select{|a| a.name == 'Delivery-Date'}&.first&.value
          end

					puts Colorize.cyan(date_now)
					puts Colorize.magenta(order_date)

					if order_date == date_now
						puts order.name
						order.tags = order.tags.remove_tag 'fulfilled'
						
						f = ShopifyAPI::Fulfillment.new
						f.prefix_options[:order_id] = order.id
						f.notify_customer = true
            f.location_id = order.location_id



						if f.save
							puts Colorize.green('saved Fulfillment')
						else
							puts Colorize.red('error saving Fulfillment')
						end

						if order.save
							puts Colorize.green('saved order')
						else
							puts Colorize.red('error saving order')
						end
					end
				end
			end
		end
	end

	def self.delete
		orders = Order.all

		start_time = Time.now

		for order in orders
			stop_time = Time.now

			processing_duration = stop_time - start_time
			wait_time = (0.5 - processing_duration).ceil
			puts "We have to wait #{wait_time} seconds then we will resume."
			sleep wait_time if wait_time > 0
			start_time = Time.now

			shopify_order = ShopifyAPI::Order.find(order.shopify_id)

			if shopify_order.cancelled_at
				puts Colorize.red(shopify_order.name + ', ' + shopify_order.email + ': ' + 'delete order')
				order.destroy
			else
				puts Colorize.cyan('do not delete')
			end
		end
	end

  def self.fulfill_marketman
    market_man = MarketMan.first
    market_man_orders = MarketManOrder.all
    
    items = []
    transactions = []

    for order in market_man_orders

      items << {
        "Type" => "MenuItem",
        "Name" => order.name,
        "ID" => order.order_id,
        "PriceWithVAT" => order.price,
        "PriceWithoutVAT" => order.price,
        "SKU" => order.sku,
        "Category" => ""
      }

      transactions << {
        "ItemCode" => order.sku,
        "ItemID" => order.order_id,
        "ItemName" => order.name,
        "PriceTotalWithVAT" => order.price.to_f * order.quantity,
        "PriceTotalWithoutVAT" => order.price.to_f * order.quantity,
        "DateUTC" => order.date_utc,
        "Quantity" => order.quantity
      }

    end

    sales_params = {
      "UniqueID" => Time.now.strftime('%Y%m%d'),
      "FromDateUTC"  => Time.now.strftime('%Y/%m/%d 00:00:00'),
      "ToDateUTC" => Time.now.strftime('%Y/%m/%d 23:59:59'),
      "TotalPriceWithVAT" => transactions.map{|t| t["PriceTotalWithVAT"]}.inject(0){|sum,x| sum + x },
      "TotalPriceWithoutVAT" => transactions.map{|t| t["PriceTotalWithoutVAT"]}.inject(0){|sum,x| sum + x },
      "Items" => items,
      "Transactions" => transactions
    }

    url = URI('https://api.marketman.com/v2/buyers/sales/SetSales')
    sale = marketman_http_request(url, market_man.auth_token, sales_params, 'post')

    MarketManOrder.destroy_all

    puts sale
  end

  def self.marketman_http_request(url, token = nil, body = nil, type = nil)
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