require 'xcodeproj'
project_path = 'MyTeam.xcodeproj'
project = Xcodeproj::Project.open(project_path)

unless project.root_object.package_references.find { |p| p.repositoryURL.include?("mlx-swift") }
  package = Xcodeproj::Project::Object::XCRemoteSwiftPackageReference.new(project, project.generate_uuid)
  package.repositoryURL = 'https://github.com/ml-explore/mlx-swift.git'
  package.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "0.22.0" }
  project.root_object.package_references << package
  
  target = project.targets.find { |t| t.name == 'MyTeam' }
  
  ["MLX", "MLXRandom"].each do |prod_name|
    dependency = Xcodeproj::Project::Object::XCSwiftPackageProductDependency.new(project, project.generate_uuid)
    dependency.product_name = prod_name
    dependency.package = package
    
    build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.product_ref = dependency
    target.frameworks_build_phase.files << build_file
  end
  
  project.save
  puts "Added mlx-swift to PBXProj successfully."
else
  puts "mlx-swift is already present."
end
