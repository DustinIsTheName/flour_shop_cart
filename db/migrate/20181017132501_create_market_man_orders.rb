class CreateMarketManOrders < ActiveRecord::Migration
  def change
    create_table :market_man_orders do |t|

      t.string :name
      t.string :order_id
      t.string :price
      t.string :sku
      t.integer :quantity
      t.string :date_utc

      t.timestamps null: false
    end
  end
end
