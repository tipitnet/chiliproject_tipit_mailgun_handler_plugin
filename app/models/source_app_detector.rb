class SourceAppDetector

  def self.initialize_strategies
    strategies = []
    strategies << ThunderBirdApp.new
    strategies << GmailApp.new
    strategies << MacMailApp.new
    strategies << OutlookApp.new
    strategies << PostBoxApp.new
    strategies << Zimbra72App.new
    strategies
  end

  def initialize
    @@strategies ||= SourceAppDetector.initialize_strategies
  end


  def detect (email)
    @@strategies.each do | mailApp |
      if mailApp.is_yours(email)
        return mailApp.class.to_s
      end
    end
    return 'unknown'
  end

end

class ThunderBirdApp
  def is_yours(email)
    email.header[:user_agent] && email.header[:user_agent].value =~ /Thunderbird/i
  end
end

class GmailApp
  def is_yours(email)
    email.header[:message_id] && email.header[:message_id].value =~ /@mail\.gmail\.com/i
  end
end

class MacMailApp
  def is_yours(email)
    email.header.to_s.index("Apple-Mail")
  end
end

class OutlookApp
  def is_yours(email)
    email.header[:x_mailer] && email.header[:x_mailer].value =~ /microsoft.+Outlook/i
  end
end

class PostBoxApp
  def is_yours(email)
    email.header[:user_agent] && email.header[:user_agent].value =~ /postbox/i
  end
end

class Zimbra72App
  def is_yours(email)
    email.header[:x_mailer] && email.header[:x_mailer].value =~ /zimbra/i
  end
end