require 'xcodeproj'
project_path = 'MyTeam/MyTeam.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 1. Find the MyTeam group
my_team_group = project.main_group.children.find { |c| c.isa == 'PBXGroup' && c.name == 'MyTeam' }

if my_team_group
  puts "Found MyTeam group: #{my_team_group.uuid}"
  
  # Get names of files in MyTeam group
  my_team_files = my_team_group.children.map(&:display_name)
  puts "Files in MyTeam group: #{my_team_files.join(', ')}"
  
  # 2. Remove these files from the Main Group if they exist there as direct children
  project.main_group.children.each do |child|
    if child.isa == 'PBXFileReference' && my_team_files.include?(child.display_name)
      puts "Removing duplicate top-level reference: #{child.display_name}"
      child.remove_from_project
    end
  end
  
  # 3. Clean up PBXFileSystemSynchronizedRootGroup if it's causing trouble
  project.root_object.main_group.children.each do |child|
    if child.isa == 'PBXFileSystemSynchronizedRootGroup'
      puts "Removing FileSystemSynchronizedRootGroup to stop auto-duplication"
      child.remove_from_project
    end
  end
end

# 4. Final duplicate build file check
project.targets.each do |target|
  seen = Set.new
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref
      name = build_file.file_ref.display_name
      if seen.include?(name)
        puts "Removing duplicate build file for #{name} in target #{target.name}"
        target.source_build_phase.remove_build_file(build_file)
      else
        seen.add(name)
      end
    end
  end
end

project.save
puts "Project cleaned and saved."
