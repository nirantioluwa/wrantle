require "test_helper"

class ContactMailerTest < ActionMailer::TestCase
  test "confirmation_email" do
    mail = ContactMailer.confirmation_email
    assert_equal "Confirmation email", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end

  test "notification_email" do
    mail = ContactMailer.notification_email
    assert_equal "Notification email", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
