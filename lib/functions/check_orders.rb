class CheckOrders

	def self.fulfill(number_of_days)
		number_of_days = number_of_days.to_i
		pages = (ShopifyAPI::Order.count/250.0).ceil

		for page in 1..pages
			orders = ShopifyAPI::Order.find(:all, params: {limit: 250, page: page})
			date_now_p = DateTime.now
			date_now = (date_now_p + number_of_days.days).strftime('%Y/%m/%d')
      date_now_dash = (date_now_p + number_of_days.days).strftime('%Y-%m-%d')

			for order in orders
        if order.name == "#15820"
          Colorize.green(order.name)
        end
        
				if order.tags.split(', ').include? 'fulfilled'
          order_date = order.note_attributes&.select{|a| a.name == 'Pickup-Date'}&.first&.value

          unless order_date
            order_date = order.note_attributes&.select{|a| a.name == 'Delivery-Date'}&.first&.value
          end

					puts Colorize.cyan(date_now)
					puts Colorize.magenta(order_date)

					if order_date == date_now or order_date == date_now_dash
						puts Colorize.blue(order.name)
						order.tags = order.tags.remove_tag 'fulfilled'

						inventory_item_id = ShopifyAPI::Variant.find(order.line_items.first.variant_id).inventory_item_id

            url = URI("https://"+ENV["SHOPIFY_DOMAIN"]+"/admin/inventory_levels.json?inventory_item_ids="+inventory_item_id.to_s)

            response = http_request url

						f = ShopifyAPI::Fulfillment.new
						f.prefix_options[:order_id] = order.id
						f.notify_customer = true
            f.location_id = response["inventory_levels"].first["location_id"]

            puts Colorize.yellow(response["inventory_levels"].first["location_id"])



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

  def self.http_request(url, body = nil, type = nil)
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

    request["Authorization"] = 'Basic ' + Base64.strict_encode64(ENV['API_KEY'] + ':' + ENV['PASSWORD'])
    request["content-type"] = 'application/json'

    if body
      request.body = body.to_json
    end

    response = http.request(request)

    puts Colorize.yellow(request.body)
    puts Colorize.yellow(response.code)

    JSON.parse response.read_body
  end

  def self.save_order(params)

    # puts Colorize.magenta(params)
    order = Order.find_by_shopify_id(params['id'])

    if order
      puts Colorize.green('found')
      if params["financial_status"] == 'paid' and params["fulfillment_status"] != 'fulfilled'
        shopify_order = ShopifyAPI::Order.find(params['id'])
        shopify_order.tags = shopify_order.tags.add_tag('fulfilled')

        if shopify_order.save
          puts Colorize.green('added fulfilled tag')
        else
          puts Colorize.red('error adding fulfilled tag')
        end
      end

      if params["financial_status"] == 'paid' and order.send_email and !params["cancelled_at"]
        puts Colorize.green('send Email')
        order.send_email = false
        order.save
        OrderMailer.order_accepted(order).deliver
      end
    else
      order_pickup_date = params["note_attributes"]&.select{|a| a["name"] == 'Pickup-Date'}
      order_pickup_location = params["note_attributes"]&.select{|a| a["name"] == 'Pickup-Location-Id'}

      if order_pickup_date.nil? || order_pickup_date.count == 0
        order_pickup_date = params["note_attributes"]&.select{|a| a["name"] == 'Delivery-Date'}
      end

      if order_pickup_location.nil? || order_pickup_location.count == 0
        order_pickup_location = params["note_attributes"]&.select{|a| a["name"] == 'Delivery-Location-Id'}
      end

      begin
        shopify_order = ShopifyAPI::Order.find(params['id'])
      rescue => e
        puts Colorize.red('Order not found')
      end

      puts Colorize.orange(order_pickup_date)
      puts Colorize.orange(order_pickup_location)

      if shopify_order
        unless order_pickup_date.nil? || order_pickup_date.count == 0
          order_pickup_date = order_pickup_date.first["value"]
          order_pickup_location = order_pickup_location.first["value"]

          pickup_date = PickupDate.find_by(date: order_pickup_date, location: order_pickup_location)

          unless pickup_date
            puts Colorize.magenta('creating PickupDate')
            pickup_date = PickupDate.create({date: order_pickup_date, location: order_pickup_location})
          else
            puts Colorize.cyan('found PickupDate')
          end

          order = Order.new
          order.shopify_id = params['id']
          order.email = params['email']
          order.customer_name = params["customer"]["first_name"]
          order.number = params["name"]
          order.order_status_url = params["order_status_url"]
          order.pickup_date_id = pickup_date.id

          order_is_over_capacity = params["note_attributes"]&.select{|a| a["name"] == 'over-capacity'}
          order_is_kiosk = params["note_attributes"]&.select{|a| a["name"] == 'kiosk-purchase'}
          order_pickup_date = params["note_attributes"]&.select{|a| a["name"] == 'Pickup-Date'}

          if order_pickup_date.nil? || order_pickup_date.count == 0
            order_pickup_date = nil
          else
            order_pickup_date = order_pickup_date.first["value"]
          end

          puts Colorize.black(order_is_kiosk)

            unless order_is_over_capacity.nil? || order_is_over_capacity.count == 0
              if order_is_over_capacity.first["value"] == "true"
                order.send_email = true

                if order_pickup_date
                  shopify_order.tags = shopify_order.tags.add_tag(order_pickup_date + '-overlimit')

                  if shopify_order.save
                    puts Colorize.green('added overlimit tag') 
                  else
                    puts Colorize.red('error adding overlimit tag')
                  end
                end
              else
                puts Colorize.magenta('else over_capacity false')
              end
            else
              puts Colorize.magenta('else over_capacity is nil')

              if order_is_kiosk.nil? || order_is_kiosk.count == 0
                shopify_order.tags = shopify_order.tags.add_tag('fulfilled')
                puts Colorize.green('staged fulfilled tag')
              end

              if order_pickup_date
                shopify_order.tags = shopify_order.tags.add_tag(order_pickup_date + '-withinlimit')
                puts Colorize.green('staged withinlimit tag')
              end

              puts Colorize.magenta(shopify_order.tags)

              if shopify_order.save
                puts Colorize.green('added fulfilled tag') 
              else
                puts Colorize.red('error adding fulfilled tag')
              end

              if order_is_kiosk.nil? || order_is_kiosk.count == 0
                unless shopify_order.tags.split(', ').include? 'Edit Order'
                  transaction = ShopifyAPI::Transaction.new
                  transaction.prefix_options[:order_id] = order.shopify_id
                  transaction.kind = 'capture'
                  if transaction.save
                    puts Colorize.green('created transaction')
                  else
                    puts Colorize.red('error creating transaction')
                    puts Colorize.red(transaction.errors.messages)
                  end
                else
                puts Colorize.yellow('Edited Order, don\'t create transaction')
                end
              end
            end

            if order.save
            puts Colorize.green('saved Order')
            else
            puts Colorize.red('error occurred saving Order')
            end

        else
          puts Colorize.cyan('irrelevant order')
        end
      end
    end

  end

end