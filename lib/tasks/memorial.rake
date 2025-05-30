namespace :memorial do
  desc "Export messages to JSON or CSV format"
  task :export, [:format] => :environment do |task, args|
    format = args[:format] || 'json'
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    
    unless %w[json csv].include?(format.downcase)
      puts "Error: Format must be 'json' or 'csv'"
      exit 1
    end
    
    messages = Message.all
    
    if messages.empty?
      puts "No messages found to export."
      exit 0
    end
    
    # Use backup directory as default
    backup_dir = File.join(Rails.root, 'backup')
    
    case format.downcase
    when 'json'
      export_to_json(messages, timestamp, backup_dir)
    when 'csv'
      export_to_csv(messages, timestamp, backup_dir)
    end
  end

  desc "Clear all messages with confirmation"
  task :clear => :environment do
    message_count = Message.count
    
    if message_count == 0
      puts "No messages to clear."
      exit 0
    end
    
    puts "⚠️  WARNING: You are about to delete #{message_count} messages!"
    puts ""
    puts "📥 BACKUP OPTIONS:"
    puts "Before deleting, would you like to create a backup?"
    puts ""
    print "Create automatic backup? (Y/n): "
    
    backup_choice = $stdin.gets&.chomp&.downcase || ''
    
    # Default to 'yes' if user just presses enter or says yes
    if backup_choice.empty? || %w[y yes].include?(backup_choice)
      puts ""
      puts "Creating backup..."
      
      # Create both JSON and CSV backups
      messages = Message.all
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      
      begin
        backup_dir = File.join(Rails.root, 'backup')
        export_to_json(messages, timestamp, backup_dir)
        export_to_csv(messages, timestamp, backup_dir)
        puts "✅ Backup completed!"
        puts ""
      rescue => e
        puts "❌ Backup failed: #{e.message}"
        puts "Please manually backup your data before proceeding."
        puts ""
        puts "Manual backup commands:"
        puts "  rails memorial:export[json]"
        puts "  rails memorial:export[csv]"
        puts ""
        print "Continue without backup? (y/N): "
        
        continue_without_backup = $stdin.gets&.chomp&.downcase || ''
        unless %w[y yes].include?(continue_without_backup)
          puts "Clear operation cancelled."
          exit 0
        end
      end
    elsif %w[n no].include?(backup_choice)
      puts ""
      puts "Skipping backup as requested."
      puts ""
      puts "Manual backup commands (if needed):"
      puts "  rails memorial:export[json]"
      puts "  rails memorial:export[csv]"
      puts ""
    else
      puts "Invalid choice. Please backup manually and run this command again."
      puts ""
      puts "Manual backup commands:"
      puts "  rails memorial:export[json]"
      puts "  rails memorial:export[csv]"
      exit 0
    end
    
    print "Are you sure you want to delete ALL #{message_count} messages? This cannot be undone! (y/N): "
    
    final_confirm = $stdin.gets&.chomp&.downcase || ''
    unless %w[y yes].include?(final_confirm)
      puts "Clear operation cancelled."
      exit 0
    end
    
    Message.delete_all
    ActiveRecord::Base.connection.execute("ALTER TABLE messages AUTO_INCREMENT = 1") if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
    
    puts "✅ All messages have been cleared successfully."
  end

  private

  def export_to_json(messages, timestamp, backup_dir = nil)
    backup_dir ||= Rails.root
    filename = "memorial_messages_#{timestamp}.json"
    filepath = File.join(backup_dir, filename)
    
    # Create backup directory if it doesn't exist
    FileUtils.mkdir_p(backup_dir) if backup_dir != Rails.root
    
    data = messages.map do |message|
      {
        id: message.id,
        name: message.name,
        content: message.content,
        created_at: message.created_at.iso8601,
        updated_at: message.updated_at.iso8601
      }
    end
    
    File.write(filepath, JSON.pretty_generate(data))
    puts "✅ Exported #{messages.count} messages to #{filepath}"
  end

  def export_to_csv(messages, timestamp, backup_dir = nil)
    require 'csv'
    backup_dir ||= Rails.root
    filename = "memorial_messages_#{timestamp}.csv"
    filepath = File.join(backup_dir, filename)
    
    # Create backup directory if it doesn't exist
    FileUtils.mkdir_p(backup_dir) if backup_dir != Rails.root
    
    CSV.open(filepath, 'w', headers: true) do |csv|
      csv << ['ID', '姓名', '留言內容', '建立時間', '更新時間']
      
      messages.each do |message|
        csv << [
          message.id,
          message.name,
          message.content,
          message.created_at.strftime('%Y-%m-%d %H:%M:%S'),
          message.updated_at.strftime('%Y-%m-%d %H:%M:%S')
        ]
      end
    end
    
    puts "✅ Exported #{messages.count} messages to #{filepath}"
  end
end