# InternalESModuleForSwiftJavaScriptCore

## Purpose
Expose JavaScriptCore ES module execution to Swift using Objective-C runtime bridging over private JSC APIs.

## How It Works
This package calls private JavaScriptCore selectors (via the Objective-C runtime) to:
- Construct `JSScript` instances of module type.
- Evaluate module scripts and receive a promise for completion.
- Attach a module loader delegate to resolve module imports.

The relevant private API surface is documented in WebKit’s JavaScriptCore sources:
https://github.com/WebKit/WebKit/tree/HEAD/Source/JavaScriptCore/API
