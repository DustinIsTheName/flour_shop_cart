class Order < ActiveRecord::Base
	belongs_to :pickup_date

	validates :date, uniqueness: true
end
