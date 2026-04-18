#!/usr/bin/env ruby
# Sprites 폴더를 folder reference로 pbxproj에 추가

require 'securerandom'

PBXPROJ = "MyTeam/MyTeam.xcodeproj/project.pbxproj"
content = File.read(PBXPROJ)

# 이미 있으면 스킵
if content.include?("lastKnownFileType = folder") && content.include?("Sprites")
  puts "⚠️  이미 Sprites folder reference가 있습니다"
  # 혹시 BuildFile은 없을 수 있으니 체크 계속
end

# UUID 생성 (24자 hex)
def new_uuid
  SecureRandom.hex(12).upcase
end

FILE_REF_UUID = "AA11BB22CC33DD44EE55FF66"
BUILD_FILE_UUID = "BB22CC33DD44EE55FF660011"

# 1. PBXFileReference 추가 (folder type)
if !content.include?(FILE_REF_UUID)
  file_ref_entry = "\t\t#{FILE_REF_UUID} /* Sprites */ = {isa = PBXFileReference; lastKnownFileType = folder; name = Sprites; path = Resources/Sprites; sourceTree = \"<group>\"; };\n"
  content.sub!("/* End PBXFileReference section */", file_ref_entry + "/* End PBXFileReference section */")
  puts "✅ PBXFileReference 추가"
end

# 2. PBXBuildFile 추가
if !content.include?(BUILD_FILE_UUID)
  build_file_entry = "\t\t#{BUILD_FILE_UUID} /* Sprites in Resources */ = {isa = PBXBuildFile; fileRef = #{FILE_REF_UUID} /* Sprites */; };\n"
  content.sub!("/* End PBXBuildFile section */", build_file_entry + "/* End PBXBuildFile section */")
  puts "✅ PBXBuildFile 추가"
end

# 3. PBXResourcesBuildPhase files 배열에 추가
if !content.include?("#{BUILD_FILE_UUID} /* Sprites in Resources */,")
  content.sub!(
    "isa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (",
    "isa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\t#{BUILD_FILE_UUID} /* Sprites in Resources */,"
  )
  puts "✅ PBXResourcesBuildPhase에 추가"
end

File.write(PBXPROJ, content)
puts "✅ project.pbxproj 저장 완료"
