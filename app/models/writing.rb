class Writing < ApplicationRecord
  belongs_to :user

  has_rich_text :content
  has_one_attached :featured_image

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true, unless: :skip_slug_validation
  validates :status, presence: true, inclusion: { in: %w[draft published] }
  validates :user, presence: true

  before_validation :set_user, on: :create
  before_validation :generate_slug, if: :should_generate_slug?

  scope :published, -> { where(status: "published").where("published_at <= ?", Time.current) }
  scope :drafts, -> { where(status: "draft") }

  def published?
    status == "published" && published_at&.<=(Time.current)
  end

  private

  def should_generate_slug?
    title_changed? || slug.blank?
  end

  def skip_slug_validation
    !should_generate_slug? && !slug_changed?
  end

  def generate_slug
    self.slug = title.to_s.parameterize
  end

  def set_user
    self.user ||= Current.user
  end

  def featured_image_attached?
    featured_image.attached?
  end
end
