task :fulfill_orders, [:days] => :environment do |t, args|
	args.with_defaults(:days => 1)
  CheckOrders.fulfill(args.days)
end

task :delete_orders => :environment do |t, args|
  CheckOrders.delete
end

task :create_script => :environment do |t, args|
  CreateScript.activate
end