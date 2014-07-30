# Load the normal Rails helper
require File.expand_path(File.dirname(__FILE__) + '/../../../../test/test_helper')

# Ensure that we are using the temporary fixture path
Engines::Testing.set_fixture_path

module Helper
  def get_mail_sample(mail_sample_filename)
    file = File.open(File.expand_path("../resources/#{mail_sample_filename.to_s}.eml", __FILE__))
    file.read
  end
end
