//
//  main.swift
//  MoveAICLI
//
//  CLI entry point for extract and analyze subcommands.
//

import Foundation

func printUsage() {
    print("""
    MoveAICLI - Pose extraction and squat analysis for MoveAI
    
    Usage:
      swift run MoveAICLI extract <video-path> [--output <output-path>]
      swift run MoveAICLI analyze <test-case-name> [--cache-dir <dir>] [--results-dir <dir>]
    
    Examples:
      swift run MoveAICLI extract MoveAITests/TestVideos/test_case_1.MOV --output MoveAITests/TestVideos/.cache/test_case_1_poses.json
      swift run MoveAICLI analyze test_case_1 --cache-dir MoveAITests/TestVideos/.cache --results-dir MoveAITests/TestVideos/.results
    """)
}

func parseArgs(_ args: [String]) -> [String: String] {
    var parsed: [String: String] = [:]
    var i = 0
    while i < args.count {
        if args[i].hasPrefix("--") {
            let key = String(args[i].dropFirst(2))
            i += 1
            if i < args.count && !args[i].hasPrefix("--") {
                parsed[key] = args[i]
                i += 1
            }
        } else {
            i += 1
        }
    }
    return parsed
}

func runExtract(args: [String]) {
    let positional = args.filter { !$0.hasPrefix("--") }
    guard let videoPath = positional.first else {
        fputs("Error: extract requires <video-path>\n", stderr)
        printUsage()
        exit(1)
    }
    
    let parsed = parseArgs(args)
    let outputPath: String
    if let out = parsed["output"] {
        outputPath = out
    } else {
        let base = (videoPath as NSString).deletingPathExtension
        let dir = (base as NSString).deletingLastPathComponent
        let name = (base as NSString).lastPathComponent
        let cacheDir = (dir as NSString).appendingPathComponent(".cache")
        outputPath = (cacheDir as NSString).appendingPathComponent("\(name)_poses.json")
    }
    
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        do {
            try await Extractor.extract(videoPath: videoPath, outputPath: outputPath)
        } catch {
            fputs("❌ Extract failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
        semaphore.signal()
    }
    semaphore.wait()
}

func runAnalyze(args: [String]) {
    let positional = args.filter { !$0.hasPrefix("--") }
    guard let testCaseName = positional.first else {
        fputs("Error: analyze requires <test-case-name>\n", stderr)
        printUsage()
        exit(1)
    }
    
    let parsed = parseArgs(args)
    let projectRoot = FileManager.default.currentDirectoryPath
    let defaultCacheDir = (projectRoot as NSString).appendingPathComponent("MoveAITests/TestVideos/.cache")
    let defaultResultsDir = (projectRoot as NSString).appendingPathComponent("MoveAITests/TestVideos/.results")
    
    let cacheDir = parsed["cache-dir"] ?? defaultCacheDir
    let resultsDir = parsed["results-dir"] ?? defaultResultsDir
    
    do {
        try Analyzer.analyze(testCaseName: testCaseName, cacheDir: cacheDir, resultsDir: resultsDir)
    } catch {
        fputs("❌ Analyze failed: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

func main() {
    let args = CommandLine.arguments.dropFirst()
    guard let subcommand = args.first else {
        printUsage()
        exit(1)
    }
    
    switch subcommand {
    case "extract":
        runExtract(args: Array(args.dropFirst()))
    case "analyze":
        runAnalyze(args: Array(args.dropFirst()))
    case "-h", "--help":
        printUsage()
        exit(0)
    default:
        fputs("Unknown subcommand: \(subcommand)\n", stderr)
        printUsage()
        exit(1)
    }
}

main()
