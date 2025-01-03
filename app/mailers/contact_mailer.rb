class ContactMailer < ApplicationMailer
  default from: "notifications@wrantle.com"

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.contact_mailer.confirmation_email.subject
  #
  def confirmation_email(contact)
    @contact = contact
    @greeting = "Hi #{@contact.name}"

    mail(
      to: @contact.email,
      subject: "We've received your #{@contact.contact_type.humanize} request"
    )
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.contact_mailer.notification_email.subject
  #
  def notification_email(contact)
    @contact = contact

    mail(
      to: [ "hi@wrantle.com", "service@wrantle.com" ],
      subject: "New #{@contact.contact_type.humanize} Request from #{@contact.name}",
      reply_to: @contact.email
    )
  end
end
