class PickupDate < ActiveRecord::Base
	has_many :orders

	validates :shopify_id, uniqueness: true
end