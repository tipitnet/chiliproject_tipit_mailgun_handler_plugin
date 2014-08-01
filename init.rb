require 'redmine'

require 'dispatcher'

Dispatcher.to_prepare :chiliproject_tipit_mailgun_handler do

  require_dependency 'attachment'

  unless Attachment.included_modules.include? TipitMailgunHandler::AttachmentPatch
    Attachment.send(:include, TipitMailgunHandler::AttachmentPatch)
  end

  require_dependency 'mailer'
  unless Mailer.included_modules.include? TipitMailgunHandler::MailerPatch
    Mailer.send(:include, TipitMailgunHandler::MailerPatch)
  end

end

Redmine::Plugin.register :chiliproject_tipit_mailgun_handler do
  name 'chiliproject_tipit_mailgun_handler_plugin'
  author 'NicoPaez'
  description 'This plugin implements several improvements to the mail handling system and integrates it with Mailgun.'
  version '1.0.0'
  url 'http://www.tipit.net/about'
end

require 'mail_part_patch'

if Rails.env.production?
  MailgunHandler.setup :api_key => ENV['MAILGUN_API_KEY']
else
  MailgunHandler.setup :api_key => 'xx'
end
ProjectDetectionStrategy.global_inbox = ENV['GLOBAL_INBOX_PROJECT']