require 'xcodeproj'
project_path = 'MyTeam.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'MyTeam' }

# Find the mlx-swift package reference (use to_hash since repository_url attr not exposed)
mlx_pkg = project.root_object.package_references.find { |ref|
  ref.to_hash['repositoryURL'].to_s.include?('mlx-swift')
}

unless mlx_pkg
  puts "❌ mlx-swift package reference not found!"
  exit 1
end

puts "✅ Found mlx-swift package: #{mlx_pkg.display_name}"

# Products to add
products_to_add = ['MLXNN', 'MLXFFT']

# Check which are already linked in frameworks build phase
frameworks_phase = target.frameworks_build_phase
existing_product_names = frameworks_phase.files.map { |f|
  f.product_ref&.product_name rescue nil
}.compact

products_to_add.each do |product_name|
  if existing_product_names.include?(product_name)
    puts "#{product_name} already linked."
    next
  end

  # Create product dependency
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = mlx_pkg
  dep.product_name = product_name

  # Add to target package product dependencies
  target.package_product_dependencies << dep

  # Add to frameworks build phase
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dep
  frameworks_phase.files << build_file

  puts "✅ Added #{product_name} to target and frameworks build phase."
end

# ------------------------------------------------------------------
# Remove duplicate Compile Sources entries for TTS spike files
# ------------------------------------------------------------------
sources_phase = target.source_build_phase
tts_files = [
  'AudioUtils.swift', 'ChatterboxConfig.swift', 'ChatterboxPipeline.swift',
  'HiFTGenerator.swift', 'LlamaModel.swift', 'T3CondEnc.swift',
  'T3Model.swift', 'VoiceEncoder.swift'
]

tts_files.each do |fname|
  matching = sources_phase.files.select { |f|
    f.file_ref&.path&.end_with?(fname) rescue false
  }
  if matching.size > 1
    # Keep first, remove the rest
    matching[1..].each do |dup|
      sources_phase.remove_build_file(dup)
    end
    puts "✅ Removed #{matching.size - 1} duplicate(s) of #{fname}"
  else
    puts "#{fname}: no duplicates found (#{matching.size} entry)"
  end
end

project.save
puts "✅ project.pbxproj saved."
