require 'xcodeproj'

project = Xcodeproj::Project.open('MyTeam.xcodeproj')
target = project.targets.find { |t| t.name == 'MyTeam' }

# Set SWIFT_STRICT_CONCURRENCY = targeted for all build configurations
# "targeted" = only flag things that are EXPLICITLY annotated, not inferred
# This is the recommended middle ground — stricter than "minimal", less broken than "complete"
target.build_configurations.each do |config|
  config.build_settings['SWIFT_STRICT_CONCURRENCY'] = 'targeted'
  puts "✅ #{config.name}: SWIFT_STRICT_CONCURRENCY = targeted"
end

project.save
puts "✅ project.pbxproj saved."
