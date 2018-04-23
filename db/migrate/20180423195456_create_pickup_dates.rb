class CreatePickupDates < ActiveRecord::Migration
  def change
    create_table :pickup_dates do |t|
    	t.string :date

      t.timestamps null: false
    end
  end
end
