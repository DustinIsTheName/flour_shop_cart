class OrderController < ApplicationController

	skip_before_filter :verify_authenticity_token
	before_filter :set_headers

	def get_info
		puts Colorize.magenta(params)

		pickup_date = PickupDate.find_by_date(params["date"])

		if pickup_date
			render json: {orders_for_the_day: pickup_date.orders.count}
		else
			render json: {orders_for_the_day: 0}
		end
	end

	def save_order
		verified = verify_webhook(request.body.read, request.headers["HTTP_X_SHOPIFY_HMAC_SHA256"])

		if verified
			# puts Colorize.magenta(params)
			order = Order.find_by_shopify_id(params['id'])

			if order
				puts Colorize.green('found')

				if params["financial_status"] == 'paid' and order.send_email
					puts Colorize.green('send Email')
					order.send_email = false
					order.save
					OrderMailer.order_accepted(order).deliver
				end
			else
				order_pickup_date = params["note_attributes"]&.select{|a| a["name"] == 'Pickup-Date'}
				shopify_order = ShopifyAPI::Order.find(params['id'])

				unless order_pickup_date.nil? || order_pickup_date.count == 0
					order_pickup_date = order_pickup_date.first["value"]

					pickup_date = PickupDate.find_by_date(order_pickup_date)

					unless pickup_date
						puts Colorize.magenta('creating PickupDate')
						pickup_date = PickupDate.create({date: order_pickup_date})
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
		    	order_pickup_date = params["note_attributes"]&.select{|a| a["name"] == 'Pickup-Date'}
		    	if order_pickup_date.nil? || order_pickup_date.count == 0
		    		order_pickup_date = nil
		    	else
		    		order_pickup_date = order_pickup_date.first["value"]
					end

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

		    		shopify_order.tags = shopify_order.tags.add_tag('fulfilled')

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

		    		transaction = ShopifyAPI::Transaction.new
		    		transaction.prefix_options[:order_id] = order.shopify_id
		    		transaction.kind = 'capture'
		    		if transaction.save
		    			puts Colorize.green('created transaction')
		    		else
		    			puts Colorize.red('error creating transaction')
		    			puts Colorize.red(transaction.errors.messages)
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

		head :ok, content_type: "text/html"
	end

	private

		def set_headers
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Request-Method'] = '*'
    end

		def verify_webhook(data, hmac_header)
			digest  = OpenSSL::Digest.new('sha256')
			calculated_hmac = Base64.encode64(OpenSSL::HMAC.digest(digest, ENV["WEBHOOK_SECRET"], data)).strip
			if calculated_hmac == hmac_header
				puts Colorize.green("Verified!")
			else
				puts Colorize.red("Invalid verification!")
			end
			calculated_hmac == hmac_header
		end
end