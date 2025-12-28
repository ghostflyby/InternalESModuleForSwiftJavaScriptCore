import JavaScriptCore
import Testing

@testable import InternalESModuleForSwiftJavaScriptCore

@Test
func evaluateSingleModule() async throws {
  let baseURL = try makeBaseDirectory()
  let source = "globalThis.result = 40 + 2;"
  let module = makeModuleSource(name: "single.js", source: source, baseURL: baseURL)
  let loader = TestModuleLoader(modulesBySpecifier: [
    module.url.absoluteString: module,
    module.url.path: module,
    module.url.lastPathComponent: module,
    "./single.js": module,
  ])

  let context = JSContext(virtualMachine: JSVirtualMachine())!
  context.moduleLoaderDelegate = loader

  let script = try ESModuleScript(
    withSource: module.source,
    andSourceURL: module.url,
    andBytecodeCache: nil,
    inVirtualMachine: context.virtualMachine
  )
  let promise = try context.evaluate(esModule: script)
  try await awaitPromise(promise, in: context)

  #expect(context.exception == nil)
  let result = context.objectForKeyedSubscript("result")?.toInt32()
  #expect(result == 42)
}

@Test
func evaluateModuleWithImport() async throws {
  let baseURL = try makeBaseDirectory()
  let dep = makeModuleSource(
    name: "dep.js",
    source: "export const answer = 42;",
    baseURL: baseURL
  )
  let main = makeModuleSource(
    name: "main.js",
    source: "import { answer } from './dep.js'; globalThis.result = answer;",
    baseURL: baseURL
  )
  let loader = TestModuleLoader(modulesBySpecifier: [
    dep.url.absoluteString: dep,
    dep.url.path: dep,
    dep.url.lastPathComponent: dep,
    "./dep.js": dep,
    main.url.absoluteString: main,
    main.url.path: main,
    main.url.lastPathComponent: main,
    "./main.js": main,
  ])

  let context = JSContext(virtualMachine: JSVirtualMachine())!
  context.moduleLoaderDelegate = loader

  let script = try ESModuleScript(
    withSource: main.source,
    andSourceURL: main.url,
    andBytecodeCache: nil,
    inVirtualMachine: context.virtualMachine
  )
  let promise = try context.evaluate(esModule: script)
  try await awaitPromise(promise, in: context)

  #expect(context.exception == nil)
  let result = context.objectForKeyedSubscript("result")?.toInt32()
  #expect(result == 42)
}

@Test
func evaluateModuleWithCustomSchemeImport() async throws {
  let dep = makeModuleSource(
    urlString: "app://dep.js",
    source: "export const answer = 42;"
  )
  let main = makeModuleSource(
    urlString: "app://main.js",
    source: "import { answer } from 'app://dep.js'; globalThis.result = answer;"
  )
  let loader = TestModuleLoader(modulesBySpecifier: [
    "app://dep.js": dep,
    "app://main.js": main,
  ])

  let context = JSContext(virtualMachine: JSVirtualMachine())!
  context.moduleLoaderDelegate = loader

  let script = try ESModuleScript(
    withSource: main.source,
    andSourceURL: main.url,
    andBytecodeCache: nil,
    inVirtualMachine: context.virtualMachine
  )
  let promise = try context.evaluate(esModule: script)
  try await awaitPromise(promise, in: context)

  #expect(context.exception == nil)
  let result = context.objectForKeyedSubscript("result")?.toInt32()
  #expect(result == 42)
}

private struct ModuleSource {
  let source: String
  let url: URL
}

private func makeBaseDirectory() throws -> URL {
  let baseURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("ESModuleTests-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
  return baseURL
}

private enum PromiseAwaitError: Error {
  case invalidPromise
  case rejected(String)
}

private func awaitPromise(_ value: JSValue, in context: JSContext) async throws {
  guard value.hasProperty("then") else {
    throw PromiseAwaitError.invalidPromise
  }
  return try await withCheckedThrowingContinuation { continuation in
    let resolve: @convention(block) (JSValue) -> Void = { _ in
      continuation.resume()
    }
    let reject: @convention(block) (JSValue) -> Void = { error in
      let message = error.toString() ?? "Promise rejected"
      continuation.resume(throwing: PromiseAwaitError.rejected(message))
    }
    let resolveValue = JSValue(object: resolve, in: context)
    let rejectValue = JSValue(object: reject, in: context)
    _ = value.invokeMethod("then", withArguments: [resolveValue as Any, rejectValue as Any])
  }
}

private func makeModuleSource(name: String, source: String, baseURL: URL) -> ModuleSource {
  let url = baseURL.appendingPathComponent(name)
  return ModuleSource(source: source, url: url)
}

private func makeModuleSource(urlString: String, source: String) -> ModuleSource {
  let url = URL(string: urlString) ?? URL(fileURLWithPath: urlString)
  return ModuleSource(source: source, url: url)
}

private final class TestModuleLoader: ESModuleLoaderDelegate {
  private let modulesBySpecifier: [String: ModuleSource]

  init(modulesBySpecifier: [String: ModuleSource]) {
    self.modulesBySpecifier = modulesBySpecifier
  }

  func fetchModule(
    in context: JSContext,
    identifier: String,
    resolve: @escaping (ESModuleScript) -> Void,
    reject: @escaping (JSValue) -> Void
  ) {
    guard let module = resolveModule(for: identifier, modulesBySpecifier: modulesBySpecifier)
    else {
      let error = JSValue(
        newErrorFromMessage: "Unknown module identifier: \(identifier)", in: context)!
      reject(error)
      return
    }
    do {
      let script = try ESModuleScript(
        withSource: module.source,
        andSourceURL: module.url,
        andBytecodeCache: nil,
        inVirtualMachine: context.virtualMachine
      )
      resolve(script)
    } catch {
      let errorValue = JSValue(newErrorFromMessage: "\(error)", in: context)!
      reject(errorValue)
    }
  }
}

private func resolveModule(
  for specifier: String,
  modulesBySpecifier: [String: ModuleSource]
) -> ModuleSource? {
  if let direct = modulesBySpecifier[specifier] {
    return direct
  }
  if specifier.hasPrefix("./") {
    let stripped = String(specifier.dropFirst(2))
    if let direct = modulesBySpecifier[stripped] {
      return direct
    }
  }
  if let url = URL(string: specifier) {
    if let direct = modulesBySpecifier[url.absoluteString] {
      return direct
    }
    if let direct = modulesBySpecifier[url.path] {
      return direct
    }
    if let direct = modulesBySpecifier[url.lastPathComponent] {
      return direct
    }
  }
  return nil
}
