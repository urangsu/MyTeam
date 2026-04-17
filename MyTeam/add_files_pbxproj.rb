require 'xcodeproj'
project_path = 'MyTeam.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'MyTeam' }
group = project.main_group.find_subpath(File.join('MyTeam'), true)

files_to_add = [
  'AudioUtils.swift',
  'ChatterboxConfig.swift',
  'ChatterboxPipeline.swift',
  'HiFTGenerator.swift',
  'LlamaModel.swift',
  'T3CondEnc.swift',
  'T3Model.swift',
  'VoiceEncoder.swift'
]

files_to_add.each do |file_name|
  unless project.files.find { |f| f.path == file_name || f.path.end_with?("/" + file_name) }
    file_ref = group.new_file(file_name)
    target.add_file_references([file_ref])
    puts "Added #{file_name} to PBXProj."
  else
    puts "#{file_name} already in PBXProj."
  end
end

project.save
puts "PBXProj saved."
