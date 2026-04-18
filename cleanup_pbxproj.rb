require 'xcodeproj'
project_path = '/Users/su/Desktop/MyTeam/MyTeam/MyTeam.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# 1. 'Contents.json'이나 '.png' 등 xcassets 내부 파일이 개별적으로 추가된 것을 모두 제거
resources_phase = target.resources_build_phase
resources_phase.files_references.each do |file_ref|
  if file_ref.path.include?('Assets.xcassets/') || file_ref.path.end_with?('Contents.json')
    puts "Removing duplicate resource reference: #{file_ref.path}"
    resources_phase.remove_file_reference(file_ref)
  end
end

# 2. Assets.xcassets 폴더 전체를 하나의 참조로만 추가 (이미 있으면 무시)
main_group = project.main_group
assets_path = '/Users/su/Desktop/MyTeam/MyTeam/Assets.xcassets'
unless project.find_file_by_path(assets_path)
  puts "Adding Assets.xcassets as a single folder reference"
  file_ref = main_group.new_reference(assets_path)
  resources_phase.add_file_reference(file_ref)
end

project.save
puts "PBXProj cleanup complete. Duplicate Contents.json references removed."
