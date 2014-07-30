require_relative '../test_helper'
require_relative '../../app/models/source_app_detector'

class SourceAppDetectorTest  < ActiveSupport::TestCase
  include Helper

  def detect(mail_type)
    raw_email = get_mail_sample mail_type
    email = Mail.new(raw_email.to_s)
    detector = SourceAppDetector.new
    detector.detect email
  end

  def test_detect_thunderbird
    result = detect(:thunderbird)
    assert_match ThunderBirdApp.to_s, result
  end

  def test_detect_gmail
    result = detect(:gmail)
    assert_match GmailApp.to_s, result
  end

  def test_detect_macmail
    result = detect(:macmail)
    assert_match MacMailApp.to_s, result
  end

  def test_detect_outlook
    result = detect(:outlook)
    assert_match OutlookApp.to_s, result
  end

  def test_detect_postbox
    result = detect(:postbox)
    assert_match PostBoxApp.to_s, result
  end

  def test_detect_zimbra72
    result = detect(:zimbra_7_2_0)
    assert_match Zimbra72App.to_s, result
  end
=begin
  def test_detect_unknown
    # we are using thunderbird as generic
    raw_email = get_mail_sample :thunderbird_reply
    email = Mail.new(raw_email.to_s)
    source_app = SourceAppDetector.new.detect email

    assert_match 'unknown', source_app
  end
=end
end