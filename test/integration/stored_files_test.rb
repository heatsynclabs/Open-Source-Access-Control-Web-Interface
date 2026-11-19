require "test_helper"

# Waivers and tool photos are streamed by the app after an access check; the
# store itself is never linked. The store read is replaced here so no S3 or
# Garage is needed.
class StoredFilesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  module FakeStore
    def read_stored(attachment, style)
      "FILE #{attachment.name} #{style}"
    end
  end
  ContractsController.prepend(FakeStore)
  ResourcesController.prepend(FakeStore)

  def person(admin: false)
    user = User.new(name: "Test Person", email: "#{SecureRandom.hex(6)}@example.invalid", password: "password",
                    postal_code: "85201", current_skills: "x", desired_skills: "x", marketing_source: "x")
    user.admin = admin
    user.define_singleton_method(:send_new_user_email) {}
    user.save!
    user
  end

  setup do
    @admin = person(admin: true)
    @contract = Contract.create!(first_name: "Ada", signed_at: Time.current, user_id: @admin.id)
    @contract.update_columns(document_file_name: "scan.pdf", document_content_type: "application/pdf",
                             document_file_size: 10, document_updated_at: Time.current)
    @resource = Resource.create!(name: "Lathe", user_id: @admin.id)
    @resource.update_columns(picture_file_name: "lathe.jpg", picture_content_type: "image/jpeg",
                             picture_file_size: 10, picture_updated_at: Time.current)
  end

  test "an admin gets the waiver, never cached, inline" do
    sign_in @admin
    get contract_document_path(@contract)
    assert_response :success
    assert_equal "FILE document original", response.body
    assert_equal "application/pdf", response.media_type
    assert_match(/no-store/, response.headers["Cache-Control"])
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_match(/inline/, response.headers["Content-Disposition"])
    get contract_document_path(@contract, download: 1)
    assert_match(/attachment; filename="waiver-#{@contract.id}.pdf"/, response.headers["Content-Disposition"])
  end

  test "a member who is not an admin cannot get a waiver" do
    sign_in person
    get contract_document_path(@contract)
    assert_not_equal "FILE document original", response.body
    assert_not_equal 200, response.status
  end

  test "nobody signed in cannot get a waiver" do
    get contract_document_path(@contract)
    assert_not_equal "FILE document original", response.body
    assert_not_equal 200, response.status
  end

  test "a PDF waiver has no preview styles, and unknown styles are not routes" do
    sign_in @admin
    get "/contracts/#{@contract.id}/document/medium"
    assert_response :not_found
    get "/contracts/#{@contract.id}/document/secret"
    assert_response :not_found
  end

  test "tool photos are public and cached" do
    get resource_photo_path(@resource, :picture, :medium)
    assert_response :success
    etag = response.headers["ETag"]
    get resource_photo_path(@resource, :picture, :medium), headers: { "If-None-Match" => etag }
    assert_response :not_modified
    get resource_photo_path(@resource, :picture, :medium)
    assert_equal "FILE picture medium", response.body
    assert_match(/public/, response.headers["Cache-Control"])
    assert_match(/sandbox/, response.headers["Content-Security-Policy"])
  end

  test "a missing photo is a 404 and only the four picture attachments are routes" do
    get resource_photo_path(@resource, :picture2)
    assert_response :not_found
    get "/resources/#{@resource.id}/photo/user/original"
    assert_response :not_found
  end

  test "uploads are checked by content type" do
    c = Contract.new(first_name: "Bob", signed_at: Time.current, document_file_name: "x.exe",
                     document_content_type: "application/x-msdownload", document_file_size: 10)
    assert_not c.valid?
    assert c.errors[:document_content_type].any? || c.errors[:document].any?
    r = Resource.new(name: "Saw", picture_file_name: "x.svg", picture_content_type: "image/svg+xml", picture_file_size: 10)
    assert_not r.valid?
  end

  test "the store settings follow the environment" do
    aws = FileStorage.options(bucket: "b", private_files: true)
    assert_nil aws[:s3_options]
    assert_equal :private, aws[:s3_permissions]
    ENV["S3_ENDPOINT"] = "http://members-files:3900"
    garage = FileStorage.options(bucket: "b", private_files: false)
    assert_equal({ endpoint: "http://members-files:3900", force_path_style: true }, garage[:s3_options])
    assert_equal false, garage[:s3_acl_enabled]
  ensure
    ENV.delete("S3_ENDPOINT")
  end
end
