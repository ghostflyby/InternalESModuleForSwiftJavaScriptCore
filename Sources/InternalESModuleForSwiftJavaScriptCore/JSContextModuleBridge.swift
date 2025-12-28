// SPDX-FileCopyrightText: 2025 ghostflyby
// SPDX-License-Identifier: Apache-2.0
import Foundation
import JavaScriptCore
import ObjectiveC.runtime

private let evaluateSelector = Selector(("evaluateJSScript:"))
private let dependenciesSelector = Selector(("dependencyIdentifiersForModuleJSScript:"))

private let evaluateIMP: EvaluateScriptIMP = {
  guard let method = class_getInstanceMethod(JSContext.self, evaluateSelector) else {
    preconditionFailure("JSContext missing evaluateJSScript:")
  }
  return unsafeBitCast(method_getImplementation(method), to: EvaluateScriptIMP.self)
}()

private let dependenciesIMP: ModuleDependenciesIMP = {
  guard let method = class_getInstanceMethod(JSContext.self, dependenciesSelector) else {
    preconditionFailure("JSContext missing moduleDependenciesForJSScript:")
  }
  return unsafeBitCast(method_getImplementation(method), to: ModuleDependenciesIMP.self)
}()

extension JSContext {
  public func evaluate(esModule: ESModuleScript) throws -> JSValue {
    guard let value = evaluateIMP(self, evaluateSelector, esModule.object) else {
      throw ESModuleError.evaluationFailed("evaluateJSScript: returned nil")
    }
    return value
  }

  public func moduleDependencyIdentifiers(for esModule: ESModuleScript) throws -> JSValue {
    guard let value = dependenciesIMP(self, dependenciesSelector, esModule.object) else {
      throw ESModuleError.dependencyLookupFailed(
        "dependencyIdentifiersForModuleJSScript: returned nil")
    }
    return value
  }
}

private typealias EvaluateScriptIMP =
  @convention(c) (
    AnyObject,
    Selector,
    AnyObject
  ) -> JSValue?

private typealias ModuleDependenciesIMP =
  @convention(c) (
    AnyObject,
    Selector,
    AnyObject
  ) -> JSValue?
