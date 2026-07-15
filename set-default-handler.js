ObjC.import("Foundation")
ObjC.import("CoreServices")

const env = $.NSProcessInfo.processInfo.environment
const bundleId = env.objectForKey("APP_BUNDLE_ID")
const contentTypes = ["com.apple.ical.ics", "public.calendar-event"]
const roles = [$.kLSRolesViewer, $.kLSRolesAll]

for (const contentType of contentTypes) {
  for (const role of roles) {
    const status = $.LSSetDefaultRoleHandlerForContentType($(contentType), role, bundleId)
    if (Number(status) !== 0) {
      throw new Error(
        "LSSetDefaultRoleHandlerForContentType failed for " +
          contentType +
          " with status " +
          Number(status)
      )
    }
  }
}
