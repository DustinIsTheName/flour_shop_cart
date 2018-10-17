class CreateMarketMen < ActiveRecord::Migration
  def change
    create_table :market_men do |t|

      t.string :auth_token
      t.string :expiration

      t.timestamps null: false
    end
  end
end
