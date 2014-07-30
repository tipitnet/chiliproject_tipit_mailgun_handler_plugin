require 'incoming'

class EmailHandler < Incoming::Strategies::Mailgun
  include ActionView::Helpers::SanitizeHelper
  include Redmine::I18n
  setup :stripped => true

  class UnauthorizedAction < StandardError; end
  class MissingInformation < StandardError; end
  class InvalidRecipients  < StandardError; end

  attr_reader :email, :user

  def initialize(request)
    @content_id_map = request.params['content-id-map']
    if @content_id_map
      @content_id_map = JSON.parse(@content_id_map)
      @content_id_map.each_key do | key |
        attach_name = @content_id_map[key]
        file_name = request.params[attach_name].original_path
        @content_id_map[key] = file_name
      end
    end
    super
  end

  # This authenticates the incoming mail
  def authenticate
    Rails.env.production? ? super : true
  end

  def receive(email)
    begin
      valid_recipients(email)
    rescue InvalidRecipients
      # the email had more recipients than chili the it should be processed
      # and should return true so the email system does not try to resend
      return true
    end
    register_source_app(email)

    @email = email
    sender_email = email.from.to_a.first.to_s.strip
    # Ignore emails received from the application emission address to avoid hell cycles
    if sender_email.downcase == Setting.mail_from.to_s.strip.downcase
      mail_logger.info  "MailHandler: ignoring email from emission address [#{sender_email}]"
      return true
    end
    @user = User.find_by_mail(sender_email) if sender_email.present?
    if @user && !@user.active?
      mail_logger.info  "MailHandler: ignoring email from non-active user [#{@user.login}]"
      return false
    end
    if @user.nil?
      # Email was submitted by an unknown user
      @user = User.anonymous
    end
    User.current = @user
    dispatch
  end

  private

  MESSAGE_ID_RE = %r{^<chiliproject\.([a-z0-9_]+)\-(\d+)\.\d+@}
  ISSUE_REPLY_SUBJECT_RE = %r{\[[^\]]*#(\d+)\]}
  MESSAGE_REPLY_SUBJECT_RE = %r{\[[^\]]*msg(\d+)\]}
  ALLOW_OVERRIDE = "project,tracker,category,priority,status,sub-status"

  def dispatch
    headers = [email.in_reply_to, email.references].flatten.compact
    if headers.detect {|h| h.to_s =~ MESSAGE_ID_RE}
      klass, object_id = $1, $2.to_i
      method_name = "receive_#{klass}_reply"
      if self.class.private_instance_methods.collect(&:to_s).include?(method_name)
        send method_name, object_id
      else
        # ignoring it
      end
    elsif m = email.subject.match(ISSUE_REPLY_SUBJECT_RE)
      receive_issue_reply(m[1].to_i)
    elsif m = email.subject.match(MESSAGE_REPLY_SUBJECT_RE)
      receive_message_reply(m[1].to_i)
    else
      dispatch_to_default
    end
  rescue ActiveRecord::RecordInvalid => e
    # TODO: send a email to the user
    mail_logger.error e.message
    Mailer.deliver_mail_handler_missing_information(user, email.subject.to_s, e.message) if Setting.mail_handler_confirmation_on_failure
    false
  rescue MissingInformation => e
    mail_logger.error "MailHandler: missing information from #{user}: #{e.message}"
    Mailer.deliver_mail_handler_missing_information(user, email.subject.to_s, e.message) if Setting.mail_handler_confirmation_on_failure
    false
  rescue UnauthorizedAction => e
    mail_logger.error "MailHandler: unauthorized attempt from #{user}"
    Mailer.deliver_mail_handler_unauthorized_action(user, email.subject.to_s) if Setting.mail_handler_confirmation_on_failure
    false
  end

  # Dispatch the mail to the default method handler, receive_issue
  #
  # This can be overridden or patched to support handling other incoming
  # email types
  def dispatch_to_default
    receive_issue
  end

  # Creates a new issue
  def receive_issue
    mail_logger.debug 'Entering receive_issue'

    detected_project_id = ProjectDetectionStrategy.new.detect_project(email.to.first, user)
    project = Project.find_by_identifier(detected_project_id)
    if project.nil?
      project = Project.find_by_identifier(ProjectDetectionStrategy.global_inbox)
    end

    mail_logger.debug "target_project: #{project.identifier}"

    issue = Issue.new(:author => user, :project => project)
    issue.safe_attributes = issue_attributes_from_keywords(issue)
    issue.safe_attributes = {'custom_field_values' => custom_field_values_from_keywords(issue)}
    issue.subject = email.subject.to_s.chomp[0,255]
    if issue.subject.blank?
      issue.subject = '(no subject)'
    end
    issue.description = cleaned_up_text_body

    # add To as watchers before saving so the watchers can reply to Chili
    mail_logger.debug "Adding watchers start"
    add_watchers(issue)
    add_default_watchers(issue)
    issue.save!
    if user.anonymous?
      email_watcher_address = email.from.first.to_s
      watcher = Watcher.new()
      watcher.email_watchers = []
      watcher.email_watchers << email_watcher_address
      watcher.watchable = issue
      watcher.user = EmailWatcherUser.default
      watcher.save
      Mailer.deliver_issue_add(issue,email_watcher_address)
    end
    mail_logger.debug "Adding watchers completed"
    mail_logger.debug "Adding attachments start"
    add_attachments(issue)
    mail_logger.debug "Adding attachments completed"

    mail_logger.info "MailHandler: issue ##{issue.id} created by #{user}"
    mail_logger.info "Email received processing completed: Issue ##{issue.id} created by #{user} \r"

    if !user.anonymous?
      Mailer.deliver_mail_handler_confirmation(issue, user, issue.subject) if Setting.mail_handler_confirmation_on_success?
    end

    issue

  end

  def add_default_watchers(issue)
    return unless issue.project.respond_to? 'default_watchers'
    mail_logger.debug "Entering add_default_watchers"
    default_watchers = issue.project.default_watchers
    mail_logger.debug "Default watchert to add [#{default_watchers}]"
    if default_watchers.nil?
      mail_logger.debug "Exiting add_default_watchers"
      return
    end
    default_watchers_list = default_watchers.split(',')
    default_watchers_list.each do | watcher_id |
      watcher = User.find(watcher_id)
      issue.add_watcher(watcher) unless watcher.nil?
    end
    mail_logger.debug "Exiting add_default_watchers"
  end

  # Adds a note to an existing issue
  def receive_issue_reply(issue_id)
    issue = Issue.find_by_id(issue_id)
    return unless issue
    # check permission
    #unless @@handler_options[:no_permission_check]
    #  raise UnauthorizedAction unless user.allowed_to?(:add_issue_notes, issue.project) || user.allowed_to?(:edit_issues, issue.project)
    #end

    # ignore CLI-supplied defaults for new issues
    #@@handler_options[:issue].clear

    issue.safe_attributes = issue_attributes_from_keywords(issue)
    issue.safe_attributes = {'custom_field_values' => custom_field_values_from_keywords(issue)}
    issue.init_journal(user, cleaned_up_text_body)
    add_attachments(issue)
    issue.save!
    mail_logger.info "MailHandler: issue ##{issue.id} updated by #{user}"
    Mailer.deliver_mail_handler_confirmation(issue.last_journal, user, email.subject) if Setting.mail_handler_confirmation_on_success
    issue.last_journal
  end

  # Reply will be added to the issue
  def receive_issue_journal_reply(journal_id)
    journal = Journal.find_by_id(journal_id)
    if journal and journal.journaled.is_a? Issue
      receive_issue_reply(journal.journaled_id)
    end
  end

  # Receives a reply to a forum message
  def receive_message_reply(message_id)
    message = Message.find_by_id(message_id)
    if message
      message = message.root

      #unless @@handler_options[:no_permission_check]
      #  raise UnauthorizedAction unless user.allowed_to?(:add_messages, message.project)
      #end

      if !message.locked?
        reply = Message.new(:subject => email.subject.gsub(%r{^.*msg\d+\]}, '').strip,
                            :content => cleaned_up_text_body)
        reply.author = user
        reply.board = message.board
        message.children << reply
        add_attachments(reply)
        Mailer.deliver_mail_handler_confirmation(message, user, reply.subject) if Setting.mail_handler_confirmation_on_success
        reply
      else
        mail_logger.info "MailHandler: ignoring reply from [#{sender_email}] to a locked topic"
      end
    end
  end

  def add_attachments(obj)
    if email.has_attachments?
      email.attachments.each do |attachment|
        Attachment.create(:container => obj,
                          :file_from_mail => attachment,
                          :author => user,
                          :content_type => attachment.content_type)
      end
    end
  end

  # Adds To and Cc as watchers of the given object if the sender has the
  # appropriate permission
  def add_watchers(obj)
    if user.allowed_to?("add_#{obj.class.name.underscore}_watchers".to_sym, obj.project)
      addresses = [email.to, email.cc].flatten.compact.uniq.collect {|a| a.strip.downcase}
      unless addresses.empty?
        watchers = User.active.find(:all, :conditions => ['LOWER(mail) IN (?)', addresses])
        watchers.each {|w| obj.add_watcher(w)}
      end
    end
  end

  def get_keyword(attr, options={})
    @keywords ||= {}
    if @keywords.has_key?(attr)
      @keywords[attr]
    else
      @keywords[attr] = begin
        if (ALLOW_OVERRIDE.include?(attr.to_s)) && (v = extract_keyword!(plain_text_body, attr, options[:format]))
          v
        end
      end
    end
  end

  # Destructively extracts the value for +attr+ in +text+
  # Returns nil if no matching keyword found
  def extract_keyword!(text, attr, format=nil)
    keys = [attr.to_s.humanize]
    if attr.is_a?(Symbol)
      keys << l("field_#{attr}", :default => '', :locale =>  user.language) if user && user.language.present?
      keys << l("field_#{attr}", :default => '', :locale =>  Setting.default_language) if Setting.default_language.present?
    end
    keys.reject! {|k| k.blank?}
    keys.collect! {|k| Regexp.escape(k)}
    format ||= '.+'
    text.gsub!(/^(#{keys.join('|')})[ \t]*:[ \t]*(#{format})\s*$/i, '')
    $2 && $2.strip
  end

  def target_project
    # TODO: other ways to specify project:
    # * parse the email To field
    # * specific project (eg. Setting.mail_handler_target_project)
    target = Project.find_by_identifier(get_keyword(:project))
    raise MissingInformation.new('Unable to determine target project') if target.nil?
    target
  end

  # Returns a Hash of issue attributes extracted from keywords in the email body
  def issue_attributes_from_keywords(issue)
    assigned_to = (k = get_keyword(:assigned_to, :override => true)) && find_user_from_keyword(k)
    assigned_to = nil if assigned_to && !issue.assignable_users.include?(assigned_to)

    attrs = {
        'tracker_id' => (k = get_keyword(:tracker)) && issue.project.trackers.find_by_name(k).try(:id),
        'status_id' =>  (k = get_keyword(:status)) && IssueStatus.find_by_name(k).try(:id),
        'priority_id' => (k = get_keyword(:priority)) && IssuePriority.find_by_name(k).try(:id),
        'category_id' => (k = get_keyword(:category)) && issue.project.issue_categories.find_by_name(k).try(:id),
        'assigned_to_id' => assigned_to.try(:id),
        'fixed_version_id' => (k = get_keyword(:fixed_version, :override => true)) && issue.project.shared_versions.find_by_name(k).try(:id),
        'start_date' => get_keyword(:start_date, :override => true, :format => '\d{4}-\d{2}-\d{2}'),
        'due_date' => get_keyword(:due_date, :override => true, :format => '\d{4}-\d{2}-\d{2}'),
        'estimated_hours' => get_keyword(:estimated_hours, :override => true),
        'done_ratio' => get_keyword(:done_ratio, :override => true, :format => '(\d|10)?0')
    }.delete_if {|k, v| v.blank? }

    if issue.new_record? && attrs['tracker_id'].nil?
      attrs['tracker_id'] = issue.project.trackers.find(:first).try(:id)
    end

    attrs
  end

  # Returns a Hash of issue custom field values extracted from keywords in the email body
  def custom_field_values_from_keywords(customized)
    customized.custom_field_values.inject({}) do |h, v|
      if value = get_keyword(v.custom_field.name, :override => true)
        h[v.custom_field.id.to_s] = value
      end
      h
    end
  end

  # Returns the text/plain part of the email
  # If not found (eg. HTML-only email), returns the body with tags removed
  def plain_text_body
    return @plain_text_body unless @plain_text_body.nil?
    parts = @email.parts.collect {|c| (c.respond_to?(:parts) && !c.parts.empty?) ? c.parts : c}.flatten
    if parts.empty?
      parts << @email
    end
    plain_text_part = parts.detect {|p| p.content_type == 'text/plain' && !p.has_attachments? }
    if plain_text_part.nil?
      # no text/plain part found, assuming html-only email
      # strip html tags and remove doctype directive
      @plain_text_body = strip_tags(@email.body.to_s)
      @plain_text_body.gsub! %r{^<!DOCTYPE .*$}, ''
    else
      @plain_text_body = plain_text_part.body.to_s
    end
    @plain_text_body.strip!
    @plain_text_body
  end

  def cleaned_up_text_body
    if (@email.html_part.nil?)
      return cleanup_body(plain_text_body)
    else
      converter = TipitMailHandler::TextileConverter.new(@email.html_part.body.to_s, @content_id_map)
      return converter.to_textile
    end
  end

  def self.full_sanitizer
    @full_sanitizer ||= HTML::FullSanitizer.new
  end

  # Creates a user account for the +email+ sender
  def self.create_user_from_email(email)
    addr = email.from_addrs.to_a.first
    if addr && !addr.spec.blank?
      user = User.new
      user.mail = addr.spec

      names = addr.name.blank? ? addr.spec.gsub(/@.*$/, '').split('.') : addr.name.split
      user.firstname = names.shift
      user.lastname = names.join(' ')
      user.lastname = '-' if user.lastname.blank?

      user.login = user.mail
      user.password = ActiveSupport::SecureRandom.hex(5)
      user.language = Setting.default_language
      user.save ? user : nil
    end
  end

  private

  # Removes the email body of text after the truncation configurations.
  def cleanup_body(body)
    delimiters = Setting.mail_handler_body_delimiters.to_s.split(/[\r\n]+/).reject(&:blank?).map {|s| Regexp.escape(s)}
    unless delimiters.empty?
      regex = Regexp.new("^[> ]*(#{ delimiters.join('|') })\s*[\r\n].*", Regexp::MULTILINE)
      body = body.gsub(regex, '')
    end
    body.strip
  end

  def find_user_from_keyword(keyword)
    user ||= User.find_by_mail(keyword)
    user ||= User.find_by_login(keyword)
    if user.nil? && keyword.match(/ /)
      firstname, lastname = *(keyword.split) # "First Last Throwaway"
      user ||= User.find_by_firstname_and_lastname(firstname, lastname)
    end
    user
  end

  def valid_recipients(email)
    if email.to.size > 1 || !email.cc.nil?
      Mailer.deliver_issue_reject_to(email.from, email.subject)
      raise InvalidRecipients
    end
  end

  def remove_issue_watcher(issue, user_email)
    user = User.find_by_mail(user_email)
    if user.nil?
      watcher = Watcher.first(:conditions => {
          :user_id => EmailWatcherUser.default.id,
          :watchable_type => 'Issue',
          :watchable_id => issue.id
      })
      watcher.email_watchers.delete(user_email)
      watcher.save
    else
      issue.remove_watcher(user)
    end
  end

  def create_logger
    tipit_logger = Logger.new("#{Rails.root}/log/received_emails.log", 'daily')
    tipit_logger.level = Logger::DEBUG
    tipit_logger.formatter = proc do |severity, datetime, progname, msg|
      "#{severity} [#{datetime}] - #{progname}: #{msg}\n"
    end
    tipit_logger
  end

  def mail_logger
    if Rails.env.production? && ENV['LOG_ENTRIES']
      @@tipit_logger ||= Le.new(ENV['LOG_ENTRIES'])
    else
      @@tipit_logger ||= create_logger
    end
  end

  def register_source_app(email)
    detector = SourceAppDetector.new
    source_app = detector.detect email
    MailRecord::create_from(email.from.first, source_app)
  end
end