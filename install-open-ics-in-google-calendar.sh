#!/bin/zsh

# This installer is intentionally small and local-only.
# It:
# - compiles the AppleScript into a Folder Action script
# - compiles the same AppleScript into a small app in ~/Applications
# - declares that app as able to open .ics files
# - asks macOS to use that app as the default .ics opener
# - optionally opens Folder Actions Setup
#
# It does not:
# - download anything
# - talk to any server
# - install a background daemon or launch agent

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
SOURCE_SCRIPT="${SCRIPT_DIR}/open-ics-in-google-calendar.applescript"
TARGET_DIR="${HOME}/Library/Scripts/Folder Action Scripts"
TARGET_SCRIPT="${TARGET_DIR}/add - open in Google Calendar.scpt"
APP_DIR="${HOME}/Applications"
APP_PATH="${APP_DIR}/Open in Google Calendar.app"
APP_INFO_PLIST="${APP_PATH}/Contents/Info.plist"
APP_BUNDLE_ID="com.dagfev.openicsingooglecalendar"
OLD_TARGET_SCRIPT="${TARGET_DIR}/calendar-download-alert.scpt"
OLD_APP_PATH="${APP_DIR}/Calendar Download Alert.app"
OLDER_TARGET_SCRIPT="${TARGET_DIR}/open-ics-in-google-calendar.scpt"
OLDER_APP_PATH="${APP_DIR}/Open ICS In Google Calendar.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
SET_DEFAULT_HANDLER="${SET_DEFAULT_HANDLER:-1}"
OPEN_FOLDER_ACTIONS_SETUP="${OPEN_FOLDER_ACTIONS_SETUP:-1}"

mkdir -p "${TARGET_DIR}"
mkdir -p "${APP_DIR}"

# Remove the old installed names so Finder does not keep picking them up.
if [[ -e "${OLD_TARGET_SCRIPT}" ]]; then
  rm -f "${OLD_TARGET_SCRIPT}"
fi
if [[ -e "${OLDER_TARGET_SCRIPT}" ]]; then
  rm -f "${OLDER_TARGET_SCRIPT}"
fi
if [[ -d "${OLD_APP_PATH}" ]]; then
  "${LSREGISTER}" -u "${OLD_APP_PATH}" >/dev/null 2>&1 || true
  rm -rf "${OLD_APP_PATH}"
fi
if [[ -d "${OLDER_APP_PATH}" ]]; then
  "${LSREGISTER}" -u "${OLDER_APP_PATH}" >/dev/null 2>&1 || true
  rm -rf "${OLDER_APP_PATH}"
fi

osacompile -o "${TARGET_SCRIPT}" "${SOURCE_SCRIPT}"
osacompile -o "${APP_PATH}" "${SOURCE_SCRIPT}"

# Give the compiled app a stable bundle id and declare .ics support.
/usr/libexec/PlistBuddy -c "Delete :CFBundleIdentifier" "${APP_INFO_PLIST}" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ${APP_BUNDLE_ID}" "${APP_INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Open in Google Calendar" "${APP_INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Open in Google Calendar" "${APP_INFO_PLIST}" >/dev/null 2>&1 || /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Open in Google Calendar" "${APP_INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "${APP_INFO_PLIST}" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "${APP_INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "${APP_INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string iCalendar File" "${APP_INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Viewer" "${APP_INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Owner" "${APP_INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "${APP_INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string com.apple.ical.ics" "${APP_INFO_PLIST}"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:1 string public.calendar-event" "${APP_INFO_PLIST}"

# Register the app with LaunchServices so Finder can see it.
"${LSREGISTER}" -f "${APP_PATH}" >/dev/null
if [[ "${SET_DEFAULT_HANDLER}" == "1" ]]; then
  # This is the only system-level preference change: make the app the default
  # viewer for .ics files, so double-clicking an .ics file opens this flow.
  APP_BUNDLE_ID_FOR_JXA="${APP_BUNDLE_ID}" osascript -l JavaScript <<'JXA'
ObjC.import('Foundation')
ObjC.import('CoreServices')
const env = $.NSProcessInfo.processInfo.environment
const bundleId = env.objectForKey('APP_BUNDLE_ID_FOR_JXA')
const contentTypes = ['com.apple.ical.ics', 'public.calendar-event']
for (const contentType of contentTypes) {
  const status = $.LSSetDefaultRoleHandlerForContentType($(contentType), $.kLSRolesViewer, bundleId)
  if (Number(status) !== 0) {
    throw new Error('LSSetDefaultRoleHandlerForContentType failed for ' + contentType + ' with status ' + Number(status))
  }
}
JXA
fi

cat <<EOF
Installed:
  ${TARGET_SCRIPT}
  ${APP_PATH}

Next step:
  1. Open Folder Actions Setup.
  2. Enable Folder Actions if prompted.
  3. Attach ${TARGET_SCRIPT} to your Downloads folder.
  4. When an .ics file is downloaded, a pre-filled Google Calendar event page will open in your browser.
  5. Double-clicking an .ics file should now open this app and launch the same pre-filled Google Calendar page.
EOF

if [[ "${OPEN_FOLDER_ACTIONS_SETUP}" == "1" ]]; then
  open "/System/Library/CoreServices/Applications/Folder Actions Setup.app"
fi
