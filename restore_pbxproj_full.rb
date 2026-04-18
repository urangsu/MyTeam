require 'xcodeproj'
project_path = '/Users/su/Desktop/MyTeam/MyTeam/MyTeam.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first
main_group = project.main_group

# Helper to add folder as a single reference (e.g. for .xcassets)
def add_folder_reference(group, path, target)
  return if group.find_file_by_path(path)
  
  file_ref = group.new_reference(path)
  target.resources_build_phase.add_file_reference(file_ref)
  puts "Added folder reference: #{path}"
end

source_dir = '/Users/su/Desktop/MyTeam/MyTeam'

# 1. Add Assets.xcassets specifically
assets_path = File.join(source_dir, 'Assets.xcassets')
if File.exist?(assets_path)
  add_folder_reference(main_group, assets_path, target)
end

# 2. Add individual files
existing_files = project.files.map(&:path).compact

Dir.glob(File.join(source_dir, '**', '*')).each do |file_path|
  next if File.directory?(file_path)
  next if file_path.include?('.xcodeproj')
  next if file_path.include?('.rb')
  next if file_path.include?('Assets.xcassets') # Already handled
  
  file_name = File.basename(file_path)
  extension = File.extname(file_name).downcase
  
  next if existing_files.any? { |p| p.include?(file_name) }

  file_ref = main_group.new_file(file_path)
  if ['.swift'].include?(extension)
    target.add_file_references([file_ref])
  else
    target.resources_build_phase.add_file_reference(file_ref)
  end
  puts "Added file: #{file_path}"
end

project.save
puts "Project fully restored."
