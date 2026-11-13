require 'test_helper'

class UserTest < ActiveSupport::TestCase
  # A complete, valid new signup.
  def signup_attrs(overrides = {})
    {
      email: "u#{SecureRandom.hex(6)}@example.com",
      password: "password", password_confirmation: "password",
      name: "Test Member", postal_code: "85201",
      current_skills: "soldering", desired_skills: "welding", marketing_source: "a friend"
    }.merge(overrides)
  end

  test "sign-up still requires the profile fields (no regression)" do
    assert User.new(signup_attrs).valid?, "a complete signup should be valid"
    assert_not User.new(signup_attrs(postal_code: "")).valid?, "postal_code required at sign-up"
    assert_not User.new(signup_attrs(current_skills: "")).valid?, "current_skills required at sign-up"
    assert_not User.new(signup_attrs(desired_skills: nil)).valid?, "desired_skills required at sign-up"
    assert_not User.new(signup_attrs(marketing_source: "")).valid?, "marketing_source required at sign-up"
  end

  test "name is always required" do
    assert_not User.new(signup_attrs(name: "")).valid?
  end

  # The bug this fixes: a pre-existing account missing the profile fields could not
  # complete a password reset, because Devise's set-password save ran full
  # validation. The `one` fixture has a blank current_skills/desired_skills/
  # marketing_source, standing in for ~292 production accounts.
  test "a legacy account missing profile fields can reset its password" do
    user = users(:one)
    assert user.reset_password("newpassword", "newpassword"),
           "reset should succeed; errors: #{user.errors.full_messages.join(', ')}"
    assert user.reload.valid_password?("newpassword")
  end

  test "a legacy account missing profile fields can still be saved on update" do
    user = users(:two)
    user.member_level = 25
    assert user.save, "admin edit should succeed; errors: #{user.errors.full_messages.join(', ')}"
  end
end
