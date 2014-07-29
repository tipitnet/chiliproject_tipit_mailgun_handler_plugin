# this is patch for a non-chili class. It is required patch to mail the incoming gem
# compatible with chili Attachment class
module Mail
  class Part < Message

    def size
      decoded.size
    end

  end

end
