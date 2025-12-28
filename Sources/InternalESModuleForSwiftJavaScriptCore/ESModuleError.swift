import Foundation
import JavaScriptCore

public enum ESModuleError: Error {
  case missingPrivateClass(String)
  case missingPrivateMethod(String)
  case scriptConstructionFailed(NSError)
  case evaluationFailed(String)
  case dependencyLookupFailed(String)
}
