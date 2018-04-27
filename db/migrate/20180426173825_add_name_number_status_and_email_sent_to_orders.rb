class AddNameNumberStatusAndEmailSentToOrders < ActiveRecord::Migration
  def change
  	add_column :orders, :customer_name, :string
  	add_column :orders, :number, :string
  	add_column :orders, :order_status_url, :string
  	add_column :orders, :send_email, :boolean
  end
end
