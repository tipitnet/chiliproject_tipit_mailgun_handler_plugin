class MailRecord < ActiveRecord::Base
  include Redmine::SafeAttributes
  safe_attributes 'email_address', 'email_client_app'

  def self.create_from(from_address, source_app)
    mail_record = MailRecord.new
    mail_record.email_address = from_address
    mail_record.email_client_app = source_app
    mail_record.save
  end

end