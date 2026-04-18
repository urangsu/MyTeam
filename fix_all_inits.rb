Encoding.default_external = Encoding::UTF_8
require 'fileutils'

files = [
    "HiFTGenerator.swift",
    "LlamaModel.swift",
    "T3CondEnc.swift",
    "T3Model.swift"
]

files.each do |file|
    path = "/Users/su/Desktop/MyTeam/MyTeam/#{file}"
    content = File.read(path)
    
    # 1. HiFTGenerator
    if file == "HiFTGenerator.swift"
        content.gsub!(/    nonisolated init\(channels: Int\) \{/, "    nonisolated override init() { fatalError() }\n\n    nonisolated init(channels: Int) {")
        content.gsub!(/    nonisolated init\(channels: Int, kernelSize: Int = 3, dilations: \[Int\] = \[1, 3, 5\]\) \{/, "    nonisolated override init() { fatalError() }\n\n    nonisolated init(channels: Int, kernelSize: Int = 3, dilations: [Int] = [1, 3, 5]) {")
        content.gsub!(/    nonisolated init\(\n        f0Channels: Int = 1,\n        hiddenSize: Int = 64\n    \) \{/, "    nonisolated override init() { fatalError() }\n\n    nonisolated init(\n        f0Channels: Int = 1,\n        hiddenSize: Int = 64\n    ) {")
        content.gsub!(/    nonisolated init\(sampleRate: Float = 24000, numHarmonics: Int = 9\) \{/, "    nonisolated override init() { fatalError() }\n\n    nonisolated init(sampleRate: Float = 24000, numHarmonics: Int = 9) {")
    end
    
    # 2. LlamaModel
    if file == "LlamaModel.swift"
        content.gsub!(/    nonisolated init\(inputSize: Int, outputSize: Int, hasBias: Bool = false\) \{/, "    nonisolated override init() { fatalError() }\n\n    nonisolated init(inputSize: Int, outputSize: Int, hasBias: Bool = false) {")
        content.gsub!(/    nonisolated init\(\n        args: LlamaConfig\n    \) \{/, "    nonisolated override init() { fatalError() }\n\n    nonisolated init(\n        args: LlamaConfig\n    ) {")
        content.gsub!(/    nonisolated init\(numLayers: Int = LlamaConfig.numHiddenLayers\) \{/, "    nonisolated override init() { fatalError() }\n\n    nonisolated init(numLayers: Int = LlamaConfig.numHiddenLayers) {")
    end
    
    # 3. T3CondEnc
    if file == "T3CondEnc.swift"
        content.gsub!(/    nonisolated init\(dim: Int = T3Consts.nChannels, nHeads: Int = 8\) \{/, "    nonisolated override init() { fatalError() }\n\n    nonisolated init(dim: Int = T3Consts.nChannels, nHeads: Int = 8) {")
        content.gsub!(/    nonisolated init\(\n        queryLen: Int = T3Consts.perceiverQueryLen,\n        dim: Int      = T3Consts.nChannels\n    \) \{/, "    nonisolated override init() { fatalError() }\n\n    nonisolated init(\n        queryLen: Int = T3Consts.perceiverQueryLen,\n        dim: Int      = T3Consts.nChannels\n    ) {")
        content.gsub!(/    nonisolated init\(\n        speakerEmbSize: Int = T3Consts.speakerEmbedSize,\n        dim: Int            = T3Consts.nChannels\n    \) \{/, "    nonisolated override init() { fatalError() }\n\n    nonisolated init(\n        speakerEmbSize: Int = T3Consts.speakerEmbedSize,\n        dim: Int            = T3Consts.nChannels\n    ) {")
    end
    
    # 4. T3Model
    if file == "T3Model.swift"
        content.gsub!(/    nonisolated init\(maxLen: Int, dim: Int\) \{/, "    nonisolated override init() { fatalError() }\n\n    nonisolated init(maxLen: Int, dim: Int) {")
        content.gsub!(/    nonisolated init\(\) \{\n        let D = T3Consts.nChannels  \/\/ 1024/, "    nonisolated override init() {\n        let D = T3Consts.nChannels  // 1024")
    end
    
    File.write(path, content)
    puts "Fixed #{file}"
end
