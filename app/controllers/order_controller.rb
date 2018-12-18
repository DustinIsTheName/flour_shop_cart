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

  # the delay in the response for this action may be causing the webhook to be deleted

	def save_order

    verified = verify_webhook(request.body.read, request.headers["HTTP_X_SHOPIFY_HMAC_SHA256"])

    if verified
      CheckOrders.save_order(params)
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