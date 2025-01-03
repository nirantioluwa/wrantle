class VerificationCode < ApplicationRecord
  belongs_to :user

  validates :code, presence: true, uniqueness: true
  validates :verification_type, presence: true, inclusion: { in: %w[admin staff] }
  validates :expires_at, presence: true

  scope :unused, -> { where(used_at: nil) }
  scope :valid, -> { unused.where("expires_at > ?", Time.current) }

  before_validation :set_code, on: :create
  before_validation :set_expiry, on: :create

  def active?
    !used_at? && expires_at > Time.current
  end

  def mark_as_used!
    update!(used_at: Time.current)
  end

  private

  def set_code
    self.code = SecureRandom.hex(3).upcase # 6 character code
  end

  def set_expiry
    self.expires_at = 30.minutes.from_now
  end
end
