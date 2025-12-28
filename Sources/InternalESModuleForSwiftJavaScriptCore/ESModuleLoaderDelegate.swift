import Foundation
import JavaScriptCore
import ObjectiveC.runtime

public protocol ESModuleLoaderDelegate: AnyObject {
  /// If your delegate keeps a reference to JSContext, prefer a weak reference to avoid cycles.
  func fetchModule(
    in context: JSContext,
    identifier: String,
    resolve: @escaping (ESModuleScript) -> Void,
    reject: @escaping (JSValue) -> Void
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
      if let bridge = associatedBridge() {
        return bridge.delegate
      }
      guard let obj = loaderGetterIMP(self, loaderGetterSelector) else { return nil }
      guard let bridge = obj as? ObjCModuleLoaderDelegateBridge else { return nil }
      storeAssociatedBridge(bridge)
      return bridge.delegate
    }
    set {
      if let delegate = newValue {
        let bridge = ObjCModuleLoaderDelegateBridge(delegate: delegate)
        storeAssociatedBridge(bridge)
        loaderSetterIMP(self, loaderSetterSelector, bridge)
      } else {
        clearAssociatedBridge()
        loaderSetterIMP(self, loaderSetterSelector, nil)
      }
    }
  }

  private func associatedBridge() -> ObjCModuleLoaderDelegateBridge? {
    objc_getAssociatedObject(self, AssociatedKeys.moduleLoaderBridge)
      as? ObjCModuleLoaderDelegateBridge
  }

  private func storeAssociatedBridge(_ bridge: ObjCModuleLoaderDelegateBridge) {
    objc_setAssociatedObject(
      self,
      AssociatedKeys.moduleLoaderBridge,
      bridge,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
  }

  private func clearAssociatedBridge() {
    objc_setAssociatedObject(
      self,
      AssociatedKeys.moduleLoaderBridge,
      nil,
      .OBJC_ASSOCIATION_ASSIGN
    )
  }
}

@objc(JSModuleLoaderDelegate)
private protocol ObjCModuleLoaderDelegate: NSObjectProtocol {
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

private final class ObjCModuleLoaderDelegateBridge: NSObject, ObjCModuleLoaderDelegate {
  let delegate: ESModuleLoaderDelegate

  init(delegate: ESModuleLoaderDelegate) {
    self.delegate = delegate
    super.init()
  }

  func fetchModule(
    in context: JSContext,
    identifier: JSValue,
    resolve: JSValue,
    reject: JSValue
  ) {
    let specifier = identifier.toString() ?? ""
    delegate.fetchModule(
      in: context,
      identifier: specifier,
      resolve: { script in
        resolve.call(withArguments: [script.object])
      },
      reject: { error in
        reject.call(withArguments: [error as Any])
      }
    )
  }

  func willEvaluateModule(_ key: NSURL) {
    delegate.willEvaluateModule(at: key as URL)
  }

  func didEvaluateModule(_ key: NSURL) {
    delegate.didEvaluateModule(at: key as URL)
  }
}

private final class AssociatedKeys: Sendable {
  private init() {}
  private static let shared = AssociatedKeys()
  nonisolated(unsafe) static let moduleLoaderBridge = UnsafeRawPointer(
    Unmanaged.passUnretained(AssociatedKeys.shared).toOpaque()
  )
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
