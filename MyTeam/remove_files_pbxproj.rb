require 'xcodeproj'
project_path = 'MyTeam.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'MyTeam' }

files_to_remove = ['AnimalTTSService.swift', 'SpeechCacheManager.swift']

files_to_remove.each do |file_name|
  file_ref = project.files.find { |f| f.path == file_name || f.path.end_with?("/" + file_name) }
  if file_ref
    # Remove from build phases
    target.source_build_phase.files_references.delete(file_ref)
    
    # Remove from group and main hierarchy
    file_ref.remove_from_project
    puts "Removed #{file_name} from PBXProj."
  else
    puts "#{file_name} not found in PBXProj."
  end
end

project.save
puts "PBXProj saved."
