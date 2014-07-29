class ProjectDetectionStrategy

	def self.global_inbox=(value)
		@@global_inbox = value
	end

	def self.global_inbox
		@@global_inbox
	end

	def detect_project (email_address, user)
		sender = email_address.split('@')[0]
		sender_parts = sender.split('+')
		if sender_parts.size > 1
			return sender_parts[1]
		else
			return user.anonymous? ? @@global_inbox : user.default_project.identifier
		end
	end

end