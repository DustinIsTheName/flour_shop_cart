task :fulfill_orders => :environment do |t, args|
  CheckOrders.fulfill
end

task :delete_orders => :environment do |t, args|
  CheckOrders.delete
end