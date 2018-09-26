class OrderController < ApplicationController

	skip_before_filter :verify_authenticity_token
	before_filter :set_headers

	def get_info
		puts Colorize.magenta(params)

		pickup_date = PickupDate.find_by(date: params["date"], location: params["location"])

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

				unless order_pickup_date
					order_pickup_date = params["note_attributes"]&.select{|a| a["name"] == 'Delivery-Date'}
				end

				unless order_pickup_location
					order_pickup_location = params["note_attributes"]&.select{|a| a["name"] == 'Delivery-Location-Id'}
				end

				shopify_order = ShopifyAPI::Order.find(params['id'])

        puts Colorize.orange(shopify_order.attributes)

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

					pickup_date

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

		head :ok, content_type: "text/html"
	end

	def cancel_order
		order = Order.find_by_shopify_id(params["id"])

		if order
			puts Colorize.red('delete order with email: ' + order.email)
			order.destroy
		end

		head :ok, content_type: "text/html"
	end

	def kiosk_order
		puts Colorize.magenta(params)

		note_attributes = []

		for attr in params["attributes"]
			note_attributes << {name: attr.first, value: attr.last}
		end

		note_attributes << {name: "kiosk-purchase", value: "true"}

		order = ShopifyAPI::Order.new
		order.email = params["kiosk_email"]
		order.customer = {
			first_name: params["kiosk_first_name"],
			last_name: params["kiosk_last_name"]
		}
		order.line_items = params["line_items"]
		order.note_attributes = note_attributes
		order.financial_status = 'partially_paid'

		if order.save
			puts Colorize.green('saved order')
			render json: order
		else
			puts Colorize.red('error saving order')
			render json: order.errors
		end

		# render json: order
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