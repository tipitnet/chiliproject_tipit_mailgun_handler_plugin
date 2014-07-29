require_dependency 'mail_handler_controller'

module TipitMailHandler

  module MailerPatch

    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
    end

    module ClassMethods
    end

    module InstanceMethods
      def issue_reject_to(address, original_subject)
        recipients [address]
        subject "Rejection: #{original_subject}"
        render_multipart('issue_reject', {})
      end

      def issue_added_by_mail(issue)
        redmine_headers 'Project' => issue.project.identifier,
                        'Issue-Id' => issue.id,
                        'Issue-Author' => issue.author.login,
                        'Type' => "Issue"
        redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to
        message_id issue
        to = issue.watchers

        recipients(to)
        subject "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] (#{issue.status.name}) #{issue.subject}"
        body :issue => issue,
             :issue_url => url_for(:controller => 'issues', :action => 'show', :id => issue)
        render_multipart('issue_add', body)
      end

    end
  end

end