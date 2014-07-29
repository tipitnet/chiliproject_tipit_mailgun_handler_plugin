require 'redmine'

require 'dispatcher'

Dispatcher.to_prepare :chiliproject_tipit_mail_handler do

  require_dependency 'attachment'

  unless Attachment.included_modules.include? TipitMailHandler::AttachmentPatch
    Attachment.send(:include, TipitMailHandler::AttachmentPatch)
  end

end

Redmine::Plugin.register :chiliproject_tipit_mail_handler do
  name 'chiliproject_tipit_mail_handler_plugin'
  author 'NicoPaez'
  description 'This plugin implements several improvements to the mail handling system.'
  version '1.0.0'
  url 'http://www.tipit.net/about'
end

require 'mail_part_patch'

if Rails.env.production?
  EmailHandler.setup :api_key => ENV['MAILGUN_API_KEY']
else
  EmailHandler.setup :api_key => 'xx'
end
ProjectDetectionStrategy.global_inbox = ENV['GLOBAL_INBOX_PROJECT']