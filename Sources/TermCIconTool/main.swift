import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "build/icons"
let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)

do {
    try IconGenerator.generateAll(in: outputURL)
} catch {
    FileHandle.standardError.write(Data("Failed to generate icons: \(error)\n".utf8))
    exit(1)
}
