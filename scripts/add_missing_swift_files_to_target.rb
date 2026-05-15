#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# Add missing Swift files to MyTeam target

require 'xcodeproj'

project_path = 'MyTeam/MyTeam.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'MyTeam' }

abort 'Target MyTeam not found' unless target

# Find or create MyTeam group
group = project.main_group.find_subpath('MyTeam', true)

files = [
  'FirstLaunchState.swift',
  'FirstLaunchStateProvider.swift',
  'FirstLaunchBannerView.swift',
  'LocalOnlyModeCardView.swift',
  'RuntimeCapabilityMode.swift',
  'StarterAction.swift',
  'StarterActionDispatcher.swift',
  'StarterActionStripView.swift',
  'Color+Hex.swift'
]

files.each do |filename|
  path = "MyTeam/#{filename}"

  # Check if file reference already exists
  file_ref = project.files.find { |f| f.real_path.to_s.end_with?(filename) }

  if file_ref.nil?
    # Create new file reference
    file_ref = group.new_file(filename)
    puts "Created file reference for #{filename}"
  else
    puts "File reference already exists for #{filename}"
  end

  # Check if file is already in source build phase
  sources_build_phase = target.source_build_phase
  if sources_build_phase.files_references.include?(file_ref)
    puts "  → Already in Compile Sources"
  else
    # Add to source build phase
    sources_build_phase.add_file_reference(file_ref)
    puts "  → Added to Compile Sources"
  end
end

project.save
puts "\n✅ Successfully added missing Swift files to MyTeam target"
