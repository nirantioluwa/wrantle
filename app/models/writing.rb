class Writing < ApplicationRecord
  belongs_to :user

  has_rich_text :content

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[draft published] }
  validates :user, presence: true

  before_validation :set_user, on: :create
  before_validation :generate_slug, if: :title_changed?

  scope :published, -> { where(status: "published").where("published_at <= ?", Time.current) }
  scope :drafts, -> { where(status: "draft") }

  private

  def generate_slug
    self.slug = title.to_s.parameterize
  end

  def set_user
    self.user ||= Current.user
  end
end
