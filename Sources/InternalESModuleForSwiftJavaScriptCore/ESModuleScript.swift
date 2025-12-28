import Foundation
import JavaScriptCore
import ObjectiveC.runtime

private let moduleScriptType: UInt = 1  // kJSScriptTypeModule

private let jsScriptClass: AnyClass = {
  guard let cls = NSClassFromString("JSScript") else {
    preconditionFailure("JSScript class is unavailable in this SDK")
  }
  return cls
}()

public struct ESModuleScript {
  let object: AnyObject
  public init(
    withSource: String, andSourceURL: URL, andBytecodeCache: URL?,
    inVirtualMachine: JSVirtualMachine
  ) throws(ESModuleError) {
    var error: NSError?
    guard
      let script = scriptConstructor(
        jsScriptClass,
        scriptConstructorSelector,
        moduleScriptType,
        withSource as NSString,
        andSourceURL as NSURL?,
        andBytecodeCache as NSURL?,
        inVirtualMachine,
        &error
      )
    else {
      throw ESModuleError.scriptConstructionFailed(
        error
          ?? NSError(
            domain: "JSScriptModule", code: 1,
            userInfo: [
              NSLocalizedDescriptionKey: "Unknown JSScript construction failure"
            ]))
    }
    self.object = script
  }
}

private let scriptConstructorSelector = Selector(
  ("scriptOfType:withSource:andSourceURL:andBytecodeCache:inVirtualMachine:error:"))

private let scriptConstructor: ScriptBuilder = {
  guard let method = class_getClassMethod(jsScriptClass, scriptConstructorSelector) else {
    preconditionFailure("JSScript missing scriptOfType:withSource:... selector")
  }
  let implementation = method_getImplementation(method)
  return unsafeBitCast(implementation, to: ScriptBuilder.self)
}()

private typealias ScriptBuilder =
  @convention(c) (
    AnyClass,
    Selector,
    UInt,
    NSString,
    NSURL?,
    NSURL?,
    JSVirtualMachine,
    UnsafeMutablePointer<NSError?>?
  ) -> AnyObject?
