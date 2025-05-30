require "application_system_test_case"

class MemorialTest < ApplicationSystemTestCase
  test "visiting the index" do
    visit root_path
    
    assert_selector "h1", text: "紀念六四"
    assert_selector ".banner img[src*='64event.jpg']"
    assert_selector "button.btn", text: "開始紀念"
    assert_selector "a.btn[href='#{say_path}']", text: "留言"
  end

  test "creating a memorial message" do
    visit say_path
    
    assert_selector "form"
    
    # Note: Form is disabled in the current implementation
    # This test documents the expected behavior
    assert_selector "input[name='message[name]']"
    assert_selector "textarea[name='message[content]']"
    assert_selector "button[type='submit']", text: "點燈"
  end

  test "displaying messages on homepage" do
    # Create test messages
    Message.create!(name: "測試用戶1", content: "測試留言1")
    Message.create!(name: "測試用戶2", content: "測試留言2")
    
    visit root_path
    
    assert_selector ".light-box", minimum: 2
    assert_text "測試用戶1"
    assert_text "測試留言1"
    assert_text "測試用戶2" 
    assert_text "測試留言2"
  end
end