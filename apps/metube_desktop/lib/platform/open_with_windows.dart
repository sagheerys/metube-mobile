import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart'
    show COINIT_APARTMENTTHREADED, CoInitializeEx, CoUninitialize;

/// Shows Windows' "Open with" dialog for [path] and plays the file in the
/// program chosen there. True when a program was chosen.
///
/// **On a thread of its own**: the dialog holds the thread that shows it
/// until it closes, and on the window's thread the whole app would stop
/// drawing meanwhile. The win32 package has no binding for this call, so
/// it is looked up in shell32 by name.
Future<bool> showOpenWith(String path) => Isolate.run(() {
  final dialog = DynamicLibrary.open('shell32.dll')
      .lookupFunction<
        Int32 Function(IntPtr owner, Pointer<_OpenAsInfo> info),
        int Function(int owner, Pointer<_OpenAsInfo> info)
      >('SHOpenWithDialog');
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  final info = calloc<_OpenAsInfo>();
  final file = path.toNativeUtf16();
  try {
    info.ref
      ..file = file
      ..fileClass = nullptr
      ..flags = _allowRegistration | _exec;
    return dialog(0, info) == 0;
  } finally {
    calloc
      ..free(file)
      ..free(info);
    CoUninitialize();
  }
});

/// The dialog offers "always use this program", and runs the file in the
/// one chosen.
const _allowRegistration = 0x1;
const _exec = 0x4;

/// Windows' OPENASINFO.
final class _OpenAsInfo extends Struct {
  external Pointer<Utf16> file;
  external Pointer<Utf16> fileClass;
  @Uint32()
  external int flags;
}
