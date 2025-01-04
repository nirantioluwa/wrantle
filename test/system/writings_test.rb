require "application_system_test_case"

class WritingsTest < ApplicationSystemTestCase
  setup do
    @writing = writings(:one)
  end

  test "visiting the index" do
    visit writings_url
    assert_selector "h1", text: "Writings"
  end

  test "should create writing" do
    visit writings_url
    click_on "New writing"

    fill_in "Published at", with: @writing.published_at
    fill_in "Slug", with: @writing.slug
    fill_in "Status", with: @writing.status
    fill_in "Title", with: @writing.title
    fill_in "User", with: @writing.user_id
    click_on "Create Writing"

    assert_text "Writing was successfully created"
    click_on "Back"
  end

  test "should update Writing" do
    visit writing_url(@writing)
    click_on "Edit this writing", match: :first

    fill_in "Published at", with: @writing.published_at.to_s
    fill_in "Slug", with: @writing.slug
    fill_in "Status", with: @writing.status
    fill_in "Title", with: @writing.title
    fill_in "User", with: @writing.user_id
    click_on "Update Writing"

    assert_text "Writing was successfully updated"
    click_on "Back"
  end

  test "should destroy Writing" do
    visit writing_url(@writing)
    click_on "Destroy this writing", match: :first

    assert_text "Writing was successfully destroyed"
  end
end
