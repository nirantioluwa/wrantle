class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :verification_codes, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Validations
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 10 }, if: -> { new_record? || changes[:password_digest] }
  validates :password, confirmation: true, if: -> { new_record? || changes[:password_digest] }
  validates :password_confirmation, presence: true, if: -> { new_record? || changes[:password_digest] }

  # Staff/Admin verification methods
  def request_staff_verification
    return false unless email_address.ends_with?("@wrantle.com")
    code = verification_codes.create!(verification_type: "staff")
    VerificationMailer.verification_code_email(code).deliver_later
    true
  end

  def request_admin_verification
    return false unless email_address.ends_with?("@wrantle.com")
    code = verification_codes.create!(verification_type: "admin")
    VerificationMailer.verification_code_email(code).deliver_later
    true
  end

  def verify_staff!(verification_code)
    code = verification_codes.unused.find_by!(
      verification_type: "staff",
      code: verification_code
    )

    code.mark_as_used!
    update!(is_staff: true)
  end

  def verify_admin!(verification_code)
    code = verification_codes.unused.find_by!(
      verification_type: "admin",
      code: verification_code
    )

    code.mark_as_used!
    update!(is_admin: true)
  end
end
