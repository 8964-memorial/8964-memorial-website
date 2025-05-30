require 'test_helper'
require 'rake'

class MemorialClearTest < ActiveSupport::TestCase
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

  test "clear task shows warning and backup options when messages exist" do
    # Mock STDIN to simulate user choosing no backup and cancelling
    mock_stdin = StringIO.new("n\nn\n")
    original_stdin = $stdin
    
    begin
      $stdin = mock_stdin
      
      output, error = capture_io do
        begin
          Rake::Task['memorial:clear'].reenable
          Rake::Task['memorial:clear'].invoke
        rescue SystemExit
        end
      end
      
      assert_includes output, "WARNING: You are about to delete 3 messages!"
      assert_includes output, "BACKUP OPTIONS:"
      assert_includes output, "Create automatic backup? (Y/n):"
      assert_includes output, "Skipping backup as requested."
      
      # Messages should still exist since user cancelled
      assert_equal 3, Message.count
    ensure
      $stdin = original_stdin
    end
  end

  test "clear task handles empty database" do
    Message.delete_all
    
    output, error = capture_io do
      begin
        Rake::Task['memorial:clear'].reenable
        Rake::Task['memorial:clear'].invoke
      rescue SystemExit
      end
    end
    
    assert_includes output, "No messages to clear."
  end

  test "clear task creates automatic backup when user chooses yes" do
    mock_stdin = StringIO.new("y\ny\n")
    original_stdin = $stdin
    
    begin
      $stdin = mock_stdin
      
      output, error = capture_io do
        Rake::Task['memorial:clear'].reenable
        Rake::Task['memorial:clear'].invoke
      end
      
      assert_includes output, "Creating backup..."
      assert_includes output, "Backup completed!"
      assert_includes output, "All messages have been cleared successfully."
      assert_equal 0, Message.count
      
      # Check that backup files were created in backup directory
      backup_dir = File.join(Rails.root, 'backup')
      json_files = Dir.glob(File.join(backup_dir, 'memorial_messages_*.json'))
      csv_files = Dir.glob(File.join(backup_dir, 'memorial_messages_*.csv'))
      assert json_files.any?
      assert csv_files.any?
    ensure
      $stdin = original_stdin
      cleanup_test_files
    end
  end

  test "clear task skips backup when user chooses no but still allows deletion" do
    mock_stdin = StringIO.new("n\ny\n")
    original_stdin = $stdin
    
    begin
      $stdin = mock_stdin
      
      output, error = capture_io do
        Rake::Task['memorial:clear'].reenable
        Rake::Task['memorial:clear'].invoke
      end
      
      assert_includes output, "Skipping backup as requested."
      assert_includes output, "All messages have been cleared successfully."
      assert_equal 0, Message.count
    ensure
      $stdin = original_stdin
    end
  end

  test "clear task cancels when final confirmation denied" do
    mock_stdin = StringIO.new("y\nn\n")
    original_stdin = $stdin
    
    begin
      $stdin = mock_stdin
      
      output, error = capture_io do
        begin
          Rake::Task['memorial:clear'].reenable
          Rake::Task['memorial:clear'].invoke
        rescue SystemExit
        end
      end
      
      assert_includes output, "Clear operation cancelled."
      assert_equal 3, Message.count
    ensure
      $stdin = original_stdin
    end
  end

  test "clear task successfully clears when fully confirmed" do
    mock_stdin = StringIO.new("y\ny\n")
    original_stdin = $stdin
    
    begin
      $stdin = mock_stdin
      
      output, error = capture_io do
        Rake::Task['memorial:clear'].reenable
        Rake::Task['memorial:clear'].invoke
      end
      
      assert_includes output, "All messages have been cleared successfully."
      assert_equal 0, Message.count
    ensure
      $stdin = original_stdin
    end
  end
end