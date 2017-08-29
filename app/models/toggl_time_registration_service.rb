# Responsible for syncing Toggl with Redmine
class TogglTimeRegistrationService
  
  def initialize(user, toggl_api_service)
    @user = user
    @toggl_api_service = toggl_api_service
  end
  
  def sync
    latest_toggl_entries = @toggl_api_service.get_toggl_entries
    return if latest_toggl_entries.empty?
    
    TogglTimeEntry.transaction do
      already_loaded_ids = TogglTimeEntry.with_ids(latest_toggl_entries.map(&:id)).map(&:id)
      new_entries = []
    
      latest_toggl_entries.each do |toggl_entry|
        next if already_loaded_ids.include?(toggl_entry.id)

        if create_time_entry(@user, toggl_entry)
          TogglTimeEntry.register_synced_entry(toggl_entry.id)
          new_entries << toggl_entry.to_h.slice(:started_at, :issue_id, :description, :duration)
        end
      end

      if new_entries.empty?
        puts "No new time entries found (#{Time.now})."
      else
        puts "New time entries pushed to Redmine (#{Time.now}):"
        if defined? Hirb
          puts Hirb::Helpers::AutoTable.render(new_entries)
        elsif respond_to? :ap
          ap new_entries
        else
          pp new_entries
        end
      end
    end
  end
  
protected

  def create_time_entry(user, toggl_entry)
    issue = Issue.find_by_id(toggl_entry.issue_id)
    if issue
      time_entry = TimeEntry.new(:project => issue.project, :issue => issue, :user => user, :spent_on => toggl_entry.started_at, :comments => toggl_entry.description)
      time_entry.hours = toggl_entry.duration
      if !time_entry.valid?
        puts "Creating time entry for issue ##{toggl_entry.issue_id} failed."
        puts "Time entry field values:"
        puts time_entry.attributes.map { |k, v| "  #{k} = #{v}" }.join("\n")
        puts "Errors:"
        puts time_entry.errors.full_messages.map { |m| "  * #{m}"}.join("\n")
      end
      time_entry.save
    else
      puts "Issue #{toggl_entry.issue_id} has not been found in Redmine. Skipping."
      false
    end
  end
  
end
