#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}

APPLESCRIPT_SOURCE="${SCRIPT_DIR}/open-in-google-calendar.applescript"
APP_INFO_TEMPLATE="${SCRIPT_DIR}/open-in-google-calendar-Info.plist"
SET_DEFAULT_HANDLER_SCRIPT="${SCRIPT_DIR}/set-default-handler.js"
APP_ICON_SOURCE="${SCRIPT_DIR}/assets/open-in-google-calendar-icon.png"

FOLDER_ACTIONS_DIR="${HOME}/Library/Scripts/Folder Action Scripts"
FOLDER_ACTION_SCRIPT_PATH="${FOLDER_ACTIONS_DIR}/Open in Google Calendar.scpt"

APPLICATION_SUPPORT_DIR="${HOME}/Library/Application Support/Open in Google Calendar"
APPLICATION_PATH="${APPLICATION_SUPPORT_DIR}/Open in Google Calendar.app"
APPLICATION_INFO_PLIST="${APPLICATION_PATH}/Contents/Info.plist"
APPLICATION_RESOURCES_DIR="${APPLICATION_PATH}/Contents/Resources"
APPLICATION_BUNDLE_ID="com.dagfev.openicsingooglecalendar"
APPLICATION_ICON_NAME="OpenInGoogleCalendar"
APPLICATION_ICON_PATH="${APPLICATION_RESOURCES_DIR}/${APPLICATION_ICON_NAME}.icns"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
SET_DEFAULT_HANDLER="${SET_DEFAULT_HANDLER:-ask}"
OPEN_FOLDER_ACTIONS_SETUP="${OPEN_FOLDER_ACTIONS_SETUP:-1}"

usage() {
  echo "Usage: $0 [--set-default | --no-default]" >&2
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --set-default)
        SET_DEFAULT_HANDLER="1"
        ;;
      --no-default)
        SET_DEFAULT_HANDLER="0"
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
    shift
  done
}

ask_about_default_handler() {
  if [[ "${SET_DEFAULT_HANDLER}" != "ask" ]]; then
    return
  fi

  if [[ ! -t 0 ]]; then
    SET_DEFAULT_HANDLER="0"
    return
  fi

  printf 'Set "Open in Google Calendar" as the default app for .ics files? [y/N] '
  read -r reply
  case "${reply}" in
    [Yy] | [Yy][Ee][Ss])
      SET_DEFAULT_HANDLER="1"
      ;;
    *)
      SET_DEFAULT_HANDLER="0"
      ;;
  esac
}

build_app_icon() {
  if [[ ! -f "${APP_ICON_SOURCE}" ]]; then
    echo "Missing app icon source: ${APP_ICON_SOURCE}" >&2
    exit 1
  fi

  local iconset_root iconset_dir size retina_size
  iconset_root=$(mktemp -d)
  iconset_dir="${iconset_root}/${APPLICATION_ICON_NAME}.iconset"
  mkdir -p "${iconset_dir}"

  for size in 16 32 128 256 512; do
    retina_size=$(( size * 2 ))
    sips -z "${size}" "${size}" "${APP_ICON_SOURCE}" --out "${iconset_dir}/icon_${size}x${size}.png" >/dev/null
    sips -z "${retina_size}" "${retina_size}" "${APP_ICON_SOURCE}" --out "${iconset_dir}/icon_${size}x${size}@2x.png" >/dev/null
  done

  iconutil -c icns "${iconset_dir}" -o "${APPLICATION_ICON_PATH}"
  rm -rf "${iconset_root}"
}

install_folder_action_and_app() {
  mkdir -p "${FOLDER_ACTIONS_DIR}" "${APPLICATION_SUPPORT_DIR}"

  osacompile -o "${FOLDER_ACTION_SCRIPT_PATH}" "${APPLESCRIPT_SOURCE}"
  osacompile -o "${APPLICATION_PATH}" "${APPLESCRIPT_SOURCE}"

  mkdir -p "${APPLICATION_RESOURCES_DIR}"
  cp "${APP_INFO_TEMPLATE}" "${APPLICATION_INFO_PLIST}"
  build_app_icon
  touch "${APPLICATION_PATH}"
  "${LSREGISTER}" -f "${APPLICATION_PATH}" >/dev/null
}

set_default_handler() {
  if [[ "${SET_DEFAULT_HANDLER}" != "1" ]]; then
    return
  fi

  APP_BUNDLE_ID="${APPLICATION_BUNDLE_ID}" osascript -l JavaScript "${SET_DEFAULT_HANDLER_SCRIPT}"
}

print_summary() {
  cat <<EOF
Installed:
  ${FOLDER_ACTION_SCRIPT_PATH}
  ${APPLICATION_PATH}

Next steps:
  1. Open Folder Actions Setup.
  2. Enable Folder Actions if prompted.
  3. Attach ${FOLDER_ACTION_SCRIPT_PATH} to your Downloads folder.
  4. When an .ics file is downloaded, a pre-filled Google Calendar event page will open in your browser.
EOF

  if [[ "${SET_DEFAULT_HANDLER}" == "1" ]]; then
    cat <<EOF
Open in Google Calendar is now the default handler for .ics files.
Double-clicking an .ics file should now open this app and launch the same pre-filled Google Calendar page.
EOF
  else
    cat <<EOF
To make it the default handler for .ics files later, run this installer again and answer yes when asked.
EOF
  fi
}

open_folder_actions_setup() {
  if [[ "${OPEN_FOLDER_ACTIONS_SETUP}" == "1" ]]; then
    open "/System/Library/CoreServices/Applications/Folder Actions Setup.app"
  fi
}

parse_args "$@"
ask_about_default_handler
install_folder_action_and_app
set_default_handler
print_summary
open_folder_actions_setup
