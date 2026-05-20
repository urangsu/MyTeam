#!/usr/bin/env ruby
# encoding: utf-8
# mac_register_round243a_files.rb
# Round 243A-OBSERVE + Round 244A-MEMORY: pbxproj 파일 등록
# 실행: ruby scripts/mac_register_round243a_files.rb
# 전제: gem install xcodeproj

require 'xcodeproj'

project_path = 'MyTeam/MyTeam.xcodeproj'
abort "project.pbxproj not found at #{project_path}" unless File.exist?(project_path)

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'MyTeam' }
abort 'Target MyTeam not found' unless target

group = project.main_group.find_subpath('MyTeam', true)
sources_build_phase = target.source_build_phase

# Round 244A: Memory Scope Foundation
round_244a = %w[
  MemoryModels.swift
  MemoryScopePolicy.swift
  MemoryStore.swift
  MemoryConsolidator.swift
  MemoryRetriever.swift
]

# Round 243A: Local Observation Foundation
round_243a = %w[
  ObservationModels.swift
  ObservationPermissionPolicy.swift
  LocalObservationService.swift
  DownloadsFolderWatcher.swift
  ClipboardContextReader.swift
  FinderSelectionReader.swift
  ScreenObservationPolicy.swift
  FileIntakeEventCardView.swift
  OfficeReviewInputPolicy.swift
]

all_files = round_244a + round_243a

all_files.each do |filename|
  swift_path = "MyTeam/#{filename}"
  unless File.exist?(swift_path)
    puts "  ⚠️  SKIP (not found on disk): #{filename}"
    next
  end

  # Check for existing file reference
  file_ref = project.files.find { |f| f.real_path.to_s.end_with?(filename) }

  if file_ref.nil?
    file_ref = group.new_file(filename)
    puts "  ➕  Created file reference: #{filename}"
  else
    puts "  ✓   Reference exists: #{filename}"
  end

  if sources_build_phase.files_references.include?(file_ref)
    puts "       Already in Compile Sources"
  else
    sources_build_phase.add_file_reference(file_ref)
    puts "       → Added to Compile Sources"
  end
end

project.save
puts "\n✅  Saved project.pbxproj"
puts "\nNext: xcodebuild -scheme MyTeam -configuration Debug build"
