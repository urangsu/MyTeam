require 'xcodeproj'
project_path = 'MyTeam/MyTeam.xcodeproj'
project = Xcodeproj::Project.open(project_path)
main_group = project.main_group

# Files to ignore (already in MyTeam or internal scripts)
my_team_group = main_group.children.find { |c| c.isa == 'PBXGroup' && c.name == 'MyTeam' }
my_team_files = my_team_group ? my_team_group.children.map(&:display_name) : []
ignore_files = ['fix_project.swift', 'clean_pbxproj.rb', 'fix_concurrency.rb'] + my_team_files

# Find all .swift files in the MyTeam root directory
Dir.glob('MyTeam/*.swift').each do |file_path|
  file_name = File.basename(file_path)
  next if ignore_files.include?(file_name)
  
  # Check if it already exists in the main group
  unless main_group.find_file_by_path(file_name)
    puts "Adding missing file to root: #{file_name}"
    file_ref = main_group.new_file(file_name)
    project.targets.first.add_file_references([file_ref])
  end
end

project.save
puts "Project restored with all necessary files."
