import Foundation
import JavaScriptCore
import ObjectiveC.runtime

public protocol ESModuleLoaderDelegate: AnyObject {
  /// If your delegate keeps a reference to JSContext, prefer a weak reference to avoid cycles.
  func fetchModule(
    in context: JSContext,
    identifier: JSValue,
    resolve: JSValue,
    reject: JSValue
  )
  func willEvaluateModule(at key: URL)
  func didEvaluateModule(at key: URL)
}

extension ESModuleLoaderDelegate {
  public func willEvaluateModule(at key: URL) {}
  public func didEvaluateModule(at key: URL) {}
}

extension JSContext {

  public var moduleLoaderDelegate: ESModuleLoaderDelegate? {
    get {
      guard let obj = loaderGetterIMP(self, loaderGetterSelector) else { return nil }
      guard let bridge = obj as? SwiftModuleLoaderDelegateBridge else { return nil }
      return bridge.delegate
    }
    set {
      if let delegate = newValue {
        let bridge = SwiftModuleLoaderDelegateBridge(delegate: delegate)
        loaderSetterIMP(self, loaderSetterSelector, bridge)
      } else {
        loaderSetterIMP(self, loaderSetterSelector, nil)
      }
    }
  }
}

private let loaderGetterSelector = Selector(("moduleLoaderDelegate"))
private let loaderSetterSelector = Selector(("setModuleLoaderDelegate:"))

private typealias ModuleLoaderDelegateGetterIMP =
  @convention(c) (AnyObject, Selector) -> AnyObject?
private typealias ModuleLoaderDelegateSetterIMP =
  @convention(c) (AnyObject, Selector, AnyObject?) -> Void

private final class SwiftModuleLoaderDelegateBridge: NSObject {
  let delegate: ESModuleLoaderDelegate

  init(delegate: ESModuleLoaderDelegate) {
    self.delegate = delegate
  }

  @objc(context:fetchModuleForIdentifier:withResolveHandler:andRejectHandler:)
  func fetchModule(
    in context: JSContext,
    identifier: JSValue,
    resolve: JSValue,
    reject: JSValue
  ) {
    delegate.fetchModule(in: context, identifier: identifier, resolve: resolve, reject: reject)
  }

  @objc(willEvaluateModule:)
  func willEvaluateModule(_ key: NSURL) {
    delegate.willEvaluateModule(at: key as URL)
  }

  @objc(didEvaluateModule:)
  func didEvaluateModule(_ key: NSURL) {
    delegate.didEvaluateModule(at: key as URL)
  }
}

private let loaderGetterIMP: ModuleLoaderDelegateGetterIMP = {
  guard let method = class_getInstanceMethod(JSContext.self, loaderGetterSelector) else {
    preconditionFailure("JSContext missing moduleLoaderDelegate")
  }
  return unsafeBitCast(method_getImplementation(method), to: ModuleLoaderDelegateGetterIMP.self)
}()

private let loaderSetterIMP: ModuleLoaderDelegateSetterIMP = {
  guard let method = class_getInstanceMethod(JSContext.self, loaderSetterSelector) else {
    preconditionFailure("JSContext missing setModuleLoaderDelegate:")
  }
  return unsafeBitCast(method_getImplementation(method), to: ModuleLoaderDelegateSetterIMP.self)
}()
