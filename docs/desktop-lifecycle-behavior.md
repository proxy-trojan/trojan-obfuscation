# Desktop Lifecycle Behavior

This document defines the **current desktop lifecycle semantics** for the Trojan-Pro client shell.

## Close / Minimize / Quit semantics

### Close (window close button)

- Default behavior: **hide to tray**
- If tray is not available: **fallback to minimize**
- Close behavior is configurable in **Settings → Window close behavior**

### Minimize

- Minimize always keeps the app running in the background
- The window can be restored from the taskbar/dock or tray menu

### Quit

- Quit performs a **best-effort disconnect** first
- After disconnect attempt, the app process exits

## Tray menu (first cut)

When tray support is available:

- **Open** → shows and focuses the main window
- **Connect** → connects the currently selected profile (disabled if no profile or already connected)
- **Disconnect** → disconnects the active session (disabled when no active session)
- **Quit** → best-effort disconnect, then exit

Tray labels include the selected profile name when available.

## Duplicate launch behavior

- A **file-lock guard** enforces single-instance startup
- If a secondary instance is launched:
  - it sends a focus signal to the primary instance (loopback IPC)
  - the primary instance records that external activation in desktop lifecycle state
  - then the secondary instance exits immediately
- Settings now surfaces the latest observed external activation for the current app session
- Dashboard now shows a user-facing “recent desktop activation” callout when the existing window was focused by a secondary launch
- External activation now nudges the shell back to the Home tab so the user can actually see the callout
- The dashboard callout can be dismissed manually and also auto-hides after a short freshness window to avoid stale noise

## Known limitations

- Tray support depends on platform plugins; on Linux without appindicator packages,
  the app now falls back to a **no-op tray plugin** rather than failing the build
- In that fallback case, desktop lifecycle behavior degrades to non-tray behavior
  (for example close falls back away from tray-specific semantics)
- Duplicate-launch focus IPC is best-effort (no guarantee on window focus on all DEs)
- Tray menu is a first-cut surface and does not yet expose advanced actions

## Configuration references

- **Window close behavior**: Settings → “Window close behavior”
- **Tray assets**: `client/assets/tray/`

## Related files

- `client/lib/platform/services/desktop_lifecycle_service.dart`
- `client/lib/platform/services/plugin_desktop_lifecycle_service.dart`
- `client/lib/platform/services/desktop_instance_guard.dart`
- `client/lib/features/settings/presentation/settings_page.dart`
