class Contact < ApplicationRecord
  # Virtual attribute for honeypot
  attr_accessor :contact_email_confirm

  # Validations
  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true
  validates :contact_type, presence: true, inclusion: { in: %w[schedule_chat request_info needs_assessment] }
  validates :message, presence: true
  validates :preferred_date, presence: true, if: :schedule_chat?
  validates :preferred_time, presence: true, if: :schedule_chat?
  # Honeypot validation
  validates :contact_email_confirm, absence: true

  # Callbacks
  before_create :set_default_status
  before_create :generate_random_id

  private

  def schedule_chat?
    contact_type == "schedule_chat"
  end

  def set_default_status
    self.status ||= "pending"
  end

  def generate_random_id
    loop do
      self.id = rand(100_000_000..999_999_999) # 9-digit random number
      break unless Contact.exists?(id: self.id)
    end
  end
end
