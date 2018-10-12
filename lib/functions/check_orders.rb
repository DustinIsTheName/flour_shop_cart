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
					puts Colorize.cyan(date_now)
					puts Colorize.magenta(order.note_attributes&.select{|a| a.name == 'Pickup-Date'}&.first&.value)

					if order.note_attributes&.select{|a| a.name == 'Pickup-Date'}&.first&.value == date_now
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

end