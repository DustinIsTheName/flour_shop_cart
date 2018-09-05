class PickupDate < ActiveRecord::Base
	has_many :orders

	validates :date, uniqueness: { scope: [:location] }
end