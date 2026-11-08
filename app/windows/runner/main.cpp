#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // SolaHelm: "Restart" starts a new copy with --wait-pid=<old pid>; wait for
  // the old copy to exit (up to 15 s) so it releases the instance lock.
  {
    const std::wstring cmd = ::GetCommandLineW();
    const std::wstring flag = L"--wait-pid=";
    const size_t at = cmd.find(flag);
    if (at != std::wstring::npos) {
      const DWORD old_pid = static_cast<DWORD>(_wtoi(cmd.c_str() + at + flag.size()));
      HANDLE old = old_pid ? ::OpenProcess(SYNCHRONIZE, FALSE, old_pid) : nullptr;
      if (old) {
        ::WaitForSingleObject(old, 15000);
        ::CloseHandle(old);
      }
    }
  }

  // SolaHelm: one instance only. A second launch (e.g. from the Start menu
  // while the app sits in the tray) brings the running window forward.
  ::CreateMutexW(nullptr, TRUE, L"Local\\SolaHelmClient.SingleInstance");
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"SolaHelm");
    if (existing) {
      ::ShowWindow(existing, SW_SHOW);
      ::ShowWindow(existing, SW_RESTORE);
      ::SetForegroundWindow(existing);
    }
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1100, 760);
  if (!window.Create(L"SolaHelm", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
