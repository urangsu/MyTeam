require 'xcodeproj'
project_path = '/Users/su/Desktop/MyTeam/MyTeam/MyTeam.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# 1. 리소스 빌드 단계(Resources Build Phase) 접근
resources_phase = target.resources_build_phase

# 2. 중복을 야기하는 모든 BuildFile 제거
# Contents.json 이라는 이름을 포함하거나 Assets.xcassets 폴더 내부의 개별 파일을 가리키는 모든 참조를 제거합니다.
resources_phase.files.each do |build_file|
  next if build_file.file_ref.nil?
  
  file_path = build_file.file_ref.path || ""
  file_name = File.basename(file_path)
  
  if file_name == "Contents.json" || file_path.include?("Assets.xcassets/")
    puts "Removing duplicate build file: #{file_path}"
    resources_phase.remove_build_file(build_file)
  end
end

# 3. Assets.xcassets 폴더 자체가 리소스 단계에 없는 경우에만 추가
assets_ref = project.main_group.find_subpath('Assets.xcassets', false)
if assets_ref
  unless resources_phase.files_references.include?(assets_ref)
    puts "Adding Assets.xcassets folder to Resources Build Phase"
    resources_phase.add_file_reference(assets_ref)
  end
else
  # 폴더 참조 자체가 없으면 새로 생성
  assets_path = '/Users/su/Desktop/MyTeam/MyTeam/Assets.xcassets'
  if File.exist?(assets_path)
    puts "Creating and adding Assets.xcassets folder reference"
    assets_ref = project.main_group.new_reference(assets_path)
    resources_phase.add_file_reference(assets_ref)
  end
end

project.save
puts "PBXProj cleanup complete. No more duplicate Contents.json errors should occur."
