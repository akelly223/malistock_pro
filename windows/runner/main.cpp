#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Nom de mutex dérivé du GUID fixe AppId de l'installateur
// (installer/setup.iss) : stable entre les versions, donc fiable pour
// détecter qu'une instance de MaliStock Pro tourne déjà.
constexpr wchar_t kMutexName[] =
    L"Global\\MaliStockPro_SingleInstance_F3BDCC0E-E93F-4725-A77B-063D747D85BC";
constexpr wchar_t kWindowTitle[] = L"MaliStock Pro";
// Nom de classe généré par le template Flutter — commun à toutes les
// apps Flutter Windows, d'où le filtrage supplémentaire par titre de
// fenêtre (kWindowTitle) dans FindWindowW pour ne cibler que MaliStock Pro.
constexpr wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

// Transmet [file_path] (chemin d'un fichier .mstk double-cliqué) à
// l'instance de MaliStock Pro déjà en cours d'exécution, via
// WM_COPYDATA, puis tente de la ramener au premier plan.
void ForwardToExistingInstance(const std::wstring& file_path) {
  HWND existing = ::FindWindowW(kWindowClassName, kWindowTitle);
  if (!existing) {
    return;
  }

  if (!file_path.empty()) {
    COPYDATASTRUCT cds = {};
    cds.dwData = 1;
    cds.cbData = static_cast<DWORD>((file_path.size() + 1) * sizeof(wchar_t));
    cds.lpData = const_cast<wchar_t*>(file_path.c_str());
    ::SendMessageW(existing, WM_COPYDATA, 0,
                   reinterpret_cast<LPARAM>(&cds));
  }

  // Windows restreint SetForegroundWindow depuis un processus tiers,
  // mais ce déclenchement suit une action utilisateur directe
  // (double-clic dans l'Explorateur), ce qui bénéficie généralement de
  // l'exemption accordée à ce mécanisme. FlashWindow en repli si l'OS
  // bloque quand même.
  if (::IsIconic(existing)) {
    ::ShowWindow(existing, SW_RESTORE);
  }
  if (!::SetForegroundWindow(existing)) {
    ::FlashWindow(existing, TRUE);
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Instance unique : si MaliStock Pro tourne déjà, on lui transmet le
  // chemin de fichier éventuel (double-clic sur un .mstk) et on quitte
  // immédiatement SANS jamais initialiser le moteur Flutter dans ce
  // second processus.
  HANDLE single_instance_mutex = ::CreateMutexW(nullptr, TRUE, kMutexName);
  bool already_running =
      single_instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS;
  if (already_running) {
    std::wstring file_path;
    if (!command_line_arguments.empty()) {
      file_path = Utf16FromUtf8(command_line_arguments[0]);
    }
    ForwardToExistingInstance(file_path);
    if (single_instance_mutex) {
      ::CloseHandle(single_instance_mutex);
    }
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kWindowTitle, origin, size)) {
    if (single_instance_mutex) {
      ::CloseHandle(single_instance_mutex);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (single_instance_mutex) {
    ::CloseHandle(single_instance_mutex);
  }
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
