#!/usr/bin/env ruby
require 'xcodeproj'

REQUIRED_SWIFT_FILES = [
  "FirstLaunchState.swift",
  "FirstLaunchStateProvider.swift",
  "FirstLaunchBannerView.swift",
  "LocalOnlyModeCardView.swift",
  "RuntimeCapabilityMode.swift",
  "StarterAction.swift",
  "StarterActionDispatcher.swift",
  "StarterActionStripView.swift",
  "Color+Hex.swift",
  "CharacterAssetManifest.swift",
  "ReleaseVisibleCharacterPolicy.swift"
]

def register_missing_files(project_path)
  project = Xcodeproj::Project.open(project_path)
  target = project.targets.first

  if target.nil?
    puts "ERROR: No targets found in project"
    exit 1
  end

  puts "Target: #{target.name}"

  registered_files = target.source_build_phase.files.map { |f| f.display_name }
  puts "Currently registered: #{registered_files.count} files"

  missing = REQUIRED_SWIFT_FILES.reject { |f| registered_files.include?(f) }

  if missing.empty?
    puts "✅ All required files already registered"
    return true
  end

  puts "⚠️  Missing #{missing.count} files:"
  missing.each { |f| puts "  - #{f}" }

  registered_count = 0
  missing.each do |filename|
    file_ref = project.new(Xcodeproj::Project::Object::PBXFileReference)
    file_ref.path = filename
    file_ref.source_tree = "<group>"
    file_ref.name = filename

    build_file = target.source_build_phase.add_file_reference(file_ref)

    if build_file
      puts "✅ Registered: #{filename}"
      registered_count += 1
    else
      puts "⚠️  Failed to register: #{filename}"
    end
  end

  if registered_count > 0
    project.save
    puts "✅ Saved project with #{registered_count} new files"
    return true
  end

  return false
rescue LoadError
  puts "ERROR: xcodeproj gem not installed. Install with: gem install xcodeproj"
  exit 1
rescue => e
  puts "ERROR: #{e.message}"
  exit 1
end

if __FILE__ == $0
  project_path = 'MyTeam/MyTeam.xcodeproj'

  unless File.directory?(project_path)
    puts "ERROR: Project not found at #{project_path}"
    exit 1
  end

  success = register_missing_files(project_path)
  exit success ? 0 : 1
end
