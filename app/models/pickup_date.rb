class PickupDate < ActiveRecord::Base
	has_many :orders

	validates :date, uniqueness: true
end