# Preview all emails at http://localhost:3000/rails/mailers/contact_mailer
class ContactMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/contact_mailer/confirmation_email
  def confirmation_email
    ContactMailer.confirmation_email
  end

  # Preview this email at http://localhost:3000/rails/mailers/contact_mailer/notification_email
  def notification_email
    ContactMailer.notification_email
  end
end
