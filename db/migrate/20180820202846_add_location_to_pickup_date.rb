class AddLocationToPickupDate < ActiveRecord::Migration
  def change
  	add_column :pickup_dates, :location, :integer
  end
end
