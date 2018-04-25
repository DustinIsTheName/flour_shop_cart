class Order < ActiveRecord::Base
	belongs_to :pickup_date

	validates :shopify_id, uniqueness: true
end
