class OrderMailer < ApplicationMailer

  def order_accepted(order)
  	@order = order
    mail(to: order.email, cc: "info@flourshop.com", subject: "ORDER #{@order.number}")
  end

end
