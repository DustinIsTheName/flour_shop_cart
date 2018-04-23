class CreateOrders < ActiveRecord::Migration
  def change
    create_table :orders do |t|
    	t.integer :shopify_id
    	t.string :email
    	t.integer :pickup_date_id

      t.timestamps null: false
    end
  end
end
