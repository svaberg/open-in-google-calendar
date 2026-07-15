#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}

APPLESCRIPT_SOURCE="${SCRIPT_DIR}/open-in-google-calendar.applescript"
APP_INFO_TEMPLATE="${SCRIPT_DIR}/open-in-google-calendar-Info.plist"
SET_DEFAULT_HANDLER_SCRIPT="${SCRIPT_DIR}/set-default-handler.js"

FOLDER_ACTIONS_DIR="${HOME}/Library/Scripts/Folder Action Scripts"
FOLDER_ACTION_SCRIPT_PATH="${FOLDER_ACTIONS_DIR}/Open in Google Calendar.scpt"

APPLICATIONS_DIR="${HOME}/Applications"
APPLICATION_PATH="${APPLICATIONS_DIR}/Open in Google Calendar.app"
APPLICATION_INFO_PLIST="${APPLICATION_PATH}/Contents/Info.plist"
APPLICATION_BUNDLE_ID="com.dagfev.openicsingooglecalendar"

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

install_folder_action_and_app() {
  mkdir -p "${FOLDER_ACTIONS_DIR}" "${APPLICATIONS_DIR}"

  osacompile -o "${FOLDER_ACTION_SCRIPT_PATH}" "${APPLESCRIPT_SOURCE}"
  osacompile -o "${APPLICATION_PATH}" "${APPLESCRIPT_SOURCE}"

  cp "${APP_INFO_TEMPLATE}" "${APPLICATION_INFO_PLIST}"
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
