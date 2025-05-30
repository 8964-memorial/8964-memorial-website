require 'test_helper'
require 'rake'

class MemorialRakeTest < ActiveSupport::TestCase
  def setup
    Rails.application.load_tasks
    Message.delete_all
    
    @test_messages = [
      Message.create!(name: '測試者1', content: '測試留言1'),
      Message.create!(name: '測試者2', content: '測試留言2'),
      Message.create!(name: '測試者3', content: '測試留言3')
    ]
  end

  def teardown
    Message.delete_all
    cleanup_test_files
  end

  test "export task creates JSON file with correct content in backup directory" do
    capture_io do
      Rake::Task['memorial:export'].reenable
      Rake::Task['memorial:export'].invoke('json')
    end
    
    backup_dir = File.join(Rails.root, 'backup')
    json_files = Dir.glob(File.join(backup_dir, 'memorial_messages_*.json'))
    assert_equal 1, json_files.length
    
    json_content = JSON.parse(File.read(json_files.first))
    assert_equal 3, json_content.length
    
    assert_equal '測試者1', json_content[0]['name']
    assert_equal '測試留言1', json_content[0]['content']
    assert json_content[0]['id'].present?
    assert json_content[0]['created_at'].present?
  end

  test "export task creates CSV file with correct content in backup directory" do
    capture_io do
      Rake::Task['memorial:export'].reenable
      Rake::Task['memorial:export'].invoke('csv')
    end
    
    backup_dir = File.join(Rails.root, 'backup')
    csv_files = Dir.glob(File.join(backup_dir, 'memorial_messages_*.csv'))
    assert_equal 1, csv_files.length
    
    csv_content = File.read(csv_files.first)
    assert_includes csv_content, '測試者1'
    assert_includes csv_content, '測試留言1'
    assert_includes csv_content, 'ID,姓名,留言內容'
  end

  test "export task fails with invalid format" do
    output, error = capture_io do
      begin
        Rake::Task['memorial:export'].reenable
        Rake::Task['memorial:export'].invoke('invalid')
      rescue SystemExit
      end
    end
    
    assert_includes output, "Error: Format must be 'json' or 'csv'"
  end

  test "export task handles empty messages" do
    Message.delete_all
    
    output, error = capture_io do
      begin
        Rake::Task['memorial:export'].reenable
        Rake::Task['memorial:export'].invoke('json')
      rescue SystemExit
      end
    end
    
    assert_includes output, "No messages found to export."
  end

  private

  def cleanup_test_files
    # Clean up files in root directory
    Dir.glob('memorial_messages_*').each { |file| File.delete(file) }
    
    # Clean up files in backup directory
    backup_dir = File.join(Rails.root, 'backup')
    if Dir.exist?(backup_dir)
      Dir.glob(File.join(backup_dir, 'memorial_messages_*')).each { |file| File.delete(file) }
    end
  end
end