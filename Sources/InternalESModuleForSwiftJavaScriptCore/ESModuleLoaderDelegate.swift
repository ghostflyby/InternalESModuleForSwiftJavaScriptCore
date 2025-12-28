import Foundation
import JavaScriptCore
import ObjectiveC.runtime

@objc(JSModuleLoaderDelegate)
public protocol ESModuleLoaderDelegate: NSObjectProtocol {
  /// If your delegate keeps a reference to JSContext, prefer a weak reference to avoid cycles.
  @objc(context:fetchModuleForIdentifier:withResolveHandler:andRejectHandler:)
  func fetchModule(
    in context: JSContext,
    identifier: JSValue,
    resolve: JSValue,
    reject: JSValue
  )

  @objc(willEvaluateModule:)
  optional func willEvaluateModule(_ key: NSURL)

  @objc(didEvaluateModule:)
  optional func didEvaluateModule(_ key: NSURL)
}

extension JSContext {
  public var moduleLoaderDelegate: ESModuleLoaderDelegate? {
    get {
      guard let obj = loaderGetterIMP(self, loaderGetterSelector) else { return nil }
      return obj as? ESModuleLoaderDelegate
    }
    set {
      loaderSetterIMP(self, loaderSetterSelector, newValue)
    }
  }
}

private let loaderGetterSelector = Selector(("moduleLoaderDelegate"))
private let loaderSetterSelector = Selector(("setModuleLoaderDelegate:"))

private typealias ModuleLoaderDelegateGetterIMP =
  @convention(c) (AnyObject, Selector) -> AnyObject?
private typealias ModuleLoaderDelegateSetterIMP =
  @convention(c) (AnyObject, Selector, AnyObject?) -> Void

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
