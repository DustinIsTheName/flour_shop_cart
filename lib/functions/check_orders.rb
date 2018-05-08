class CheckOrders

	def self.fulfill
		orders = ShopifyAPI::Order.all
		date_now = DateTime.now.strftime('%Y/%m/%d')

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