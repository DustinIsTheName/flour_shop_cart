class OrderMailer < ApplicationMailer

  def order_accepted(order)
  	@order = order
    mail(to: order.email, subject: "ORDER #{@order.number}")
  end

end
