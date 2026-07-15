# Open ICS In Google Calendar

Minimal macOS tool for opening `.ics` files as pre-filled Google Calendar events.

Right now it does one thing:

- when a new `.ics` file lands in `Downloads`, it opens a pre-filled Google
  Calendar event
- when you open a local `.ics` file directly, it opens the same pre-filled
  Google Calendar flow
- you review it in the browser and click the final save button yourself, or
  just close the page if you do not want to add it
- it uses only built-in macOS tools, so it should work on a clean Mac
- no Python, Google API, or OAuth setup is required

## Trust Notes

This project is meant to be easy to inspect.

The installer does only these things:

- compiles `open-ics-in-google-calendar.applescript` into a Folder Action script
- compiles the same source into a small app in `~/Applications`
- marks that app as able to open `.ics` files
- sets that app as the default opener for `.ics` files
- opens macOS Folder Actions Setup

The script does only these things when triggered:

- reads one local `.ics` file
- parses the first `VEVENT`
- builds a Google Calendar event-creation URL
- opens that URL in your default browser

What it does not do:

- no Google API
- no OAuth login flow
- no hidden background service
- no launch agent, login item, or daemon
- no auto-update
- no analytics or telemetry
- no `curl` or other network call from the installer

The only networked action is this:

- after you click `Open`, your browser is sent to `https://calendar.google.com/calendar/render?...`

## Quick Start

Clone this repo from GitHub, or download it as a ZIP and open the folder in
Terminal.

Run:

```sh
chmod +x install-open-ics-in-google-calendar.sh
./install-open-ics-in-google-calendar.sh
```

The installer will:

- compile the AppleScript into your macOS Folder Action Scripts folder
- install a tiny `.app` in `~/Applications`
- set that app as the default opener for `.ics` files
- open Folder Actions Setup

In Folder Actions Setup:

1. Enable Folder Actions.
2. Add your `Downloads` folder if it is not already listed.
3. Attach `add - open in Google Calendar.scpt` to that folder.
4. Stay signed in to Google Calendar in your browser.

![Folder Actions Setup](docs/folder-actions-setup.png)

After installation, double-clicking an `.ics` file should also open a
pre-filled Google Calendar event in your browser.

That also makes double-clicking a good way to test the flow without waiting for
a fresh download.

## Files

- `open-ics-in-google-calendar.applescript` contains all runtime behavior
- `install-open-ics-in-google-calendar.sh` installs the Folder Action and app bundle
- `docs/folder-actions-setup.png` is the setup screenshot

## Audit Tip

If you want to inspect the repository quickly, these are the main things to
look for:

- `open location` in `open-ics-in-google-calendar.applescript`
- `LSSetDefaultRoleHandlerForContentType` in `install-open-ics-in-google-calendar.sh`
- the absence of `curl`, `wget`, `launchctl`, and similar commands

More details can be added later as the script grows.
