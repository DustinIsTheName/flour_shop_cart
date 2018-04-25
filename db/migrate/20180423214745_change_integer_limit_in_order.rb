class ChangeIntegerLimitInOrder < ActiveRecord::Migration
  def change
  	change_column :orders, :shopify_id, :integer, limit: 8
  end
end
