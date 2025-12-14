// FFI loader - this file provides conditional exports
// On iOS: exports stubs that don't load the Rust library
// On other platforms: exports the real FFI implementation

export 'frb_generated.dart'
    if (dart.library.html) 'ffi_stub.dart'; // Web uses stub
