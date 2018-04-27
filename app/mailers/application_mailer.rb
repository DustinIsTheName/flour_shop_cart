class ApplicationMailer < ActionMailer::Base
  default from: "orders@flourshop.com"
  layout 'mailer'
end
