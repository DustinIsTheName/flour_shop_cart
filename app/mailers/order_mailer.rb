class OrderMailer < ApplicationMailer

  def order_accepted(order)
    mail(to: order.email, subject: '')
  end

end
