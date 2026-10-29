class ResourceCategory < ActiveRecord::Base
  has_many :resources

  before_destroy :has_resources?

  private

  # A category that still holds tools stays. Since Rails 5 a callback must
  # throw :abort to stop the delete (returning false no longer does).
  def has_resources?
    return if resources.count == 0
    errors.add(:base, "Cannot delete category with associated resources")
    throw :abort
  end
end
