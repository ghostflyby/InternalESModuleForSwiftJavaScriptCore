import Foundation
import JavaScriptCore
import ObjectiveC.runtime

private typealias ObjCModuleLoaderDelegate = NSObject

public struct ESModuleLoaderDelegate {
  fileprivate let object: ObjCModuleLoaderDelegate

  fileprivate init(object: ObjCModuleLoaderDelegate) {
    self.object = object
  }

  public init?(bridging object: AnyObject) {
    guard let delegate = object as? ObjCModuleLoaderDelegate else { return nil }
    guard delegate.responds(to: fetchModuleSelector) else { return nil }
    self.object = delegate
  }
}

extension ESModuleLoaderDelegate {
  public func fetchModule(
    in context: JSContext,
    identifier: JSValue,
    resolve: JSValue,
    reject: JSValue
  ) {
    moduleFetchIMP(object, fetchModuleSelector, context, identifier, resolve, reject)
  }

  public func willEvaluateModule(at key: URL) {
    invokeLifecycleSelector(willEvaluateSelector, with: key)
  }

  public func didEvaluateModule(at key: URL) {
    invokeLifecycleSelector(didEvaluateSelector, with: key)
  }

  private var moduleFetchIMP: ModuleFetchIMP {
    guard let method = object.method(for: fetchModuleSelector) else {
      preconditionFailure("moduleLoaderDelegate missing required fetch implementation")
    }
    return unsafeBitCast(method, to: ModuleFetchIMP.self)
  }

  private func invokeLifecycleSelector(_ selector: Selector, with key: URL) {
    guard let imp = lifecycleIMP(for: selector) else { return }
    imp(object, selector, key as NSURL)
  }

  private func lifecycleIMP(for selector: Selector) -> ModuleLifecycleIMP? {
    guard object.responds(to: selector) else { return nil }
    guard let method = object.method(for: selector) else { return nil }
    return unsafeBitCast(method, to: ModuleLifecycleIMP.self)
  }
}

extension JSContext {

  public var moduleLoaderDelegate: ESModuleLoaderDelegate? {
    get {
      guard let obj = loaderGetterIMP(self, loaderGetterSelector) else { return nil }
      guard let delegate = obj as? ObjCModuleLoaderDelegate else {
        preconditionFailure("moduleLoaderDelegate must inherit from NSObject")
      }
      return ESModuleLoaderDelegate(object: delegate)
    }
    set {
      loaderSetterIMP(self, loaderSetterSelector, newValue?.object)
    }
  }
}

private let loaderGetterSelector = Selector(("moduleLoaderDelegate"))
private let loaderSetterSelector = Selector(("setModuleLoaderDelegate:"))
private let fetchModuleSelector = Selector(
  ("context:fetchModuleForIdentifier:withResolveHandler:andRejectHandler:"))
private let willEvaluateSelector = Selector(("willEvaluateModule:"))
private let didEvaluateSelector = Selector(("didEvaluateModule:"))

private typealias ModuleLoaderDelegateGetterIMP =
  @convention(c) (AnyObject, Selector) -> AnyObject?
private typealias ModuleLoaderDelegateSetterIMP =
  @convention(c) (AnyObject, Selector, AnyObject?) -> Void

private typealias ModuleFetchIMP =
  @convention(c) (
    AnyObject,
    Selector,
    JSContext,
    JSValue,
    JSValue,
    JSValue
  ) -> Void

private typealias ModuleLifecycleIMP =
  @convention(c) (
    AnyObject,
    Selector,
    NSURL
  ) -> Void

/// Accessor helpers for the private JSModuleLoaderDelegate plumbing on JSContext.
enum JSModuleLoaderDelegateBridge {
  private static let getterSelector = Selector(("moduleLoaderDelegate"))
  private static let setterSelector = Selector(("setModuleLoaderDelegate:"))

  private static let getter: DelegateGetter = {
    guard let method = class_getInstanceMethod(JSContext.self, getterSelector) else {
      preconditionFailure("JSContext missing moduleLoaderDelegate getter")
    }
    let implementation = method_getImplementation(method)
    return unsafeBitCast(implementation, to: DelegateGetter.self)
  }()

  private static let setter: DelegateSetter = {
    guard let method = class_getInstanceMethod(JSContext.self, setterSelector) else {
      preconditionFailure("JSContext missing moduleLoaderDelegate setter")
    }
    let implementation = method_getImplementation(method)
    return unsafeBitCast(implementation, to: DelegateSetter.self)
  }()

  static func currentDelegate(in context: JSContext) -> AnyObject? {
    getter(context, getterSelector)
  }

  static func setDelegate(_ delegate: AnyObject?, for context: JSContext) {
    setter(context, setterSelector, delegate)
  }
}

private typealias DelegateGetter = @convention(c) (AnyObject, Selector) -> AnyObject?
private typealias DelegateSetter = @convention(c) (AnyObject, Selector, AnyObject?) -> Void

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
