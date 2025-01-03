class VerificationMailer < ApplicationMailer
  default from: "verification@wrantle.com"

  def verification_code_email(verification_code)
    @verification_code = verification_code
    @user = verification_code.user
    @code = verification_code.code
    @type = verification_code.verification_type

    mail to: @user.email_address,
         subject: "Your #{@type.titleize} Verification Code"
  end
end
