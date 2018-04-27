task :fulfill_orders => :environment do |t, args|
  CheckOrders.fulfill
end