(*
Open In Google Calendar

Opens a downloaded .ics file as a pre-filled Google Calendar event.
Reads the file locally, takes the first VEVENT, builds the Google Calendar URL,
and opens that page in the default browser.
*)

use framework "Foundation"
use scripting additions

property app_title : "Open in Google Calendar"

-- Folder Action entry point.
on adding folder items to this_folder after receiving added_items
	repeat with added_item in added_items
		my maybe_open_calendar_item(added_item)
	end repeat
end adding folder items to

-- App entry point when a user double-clicks an .ics file.
on open dropped_items
	repeat with dropped_item in dropped_items
		my maybe_open_calendar_item(dropped_item)
	end repeat
end open

-- Shared trigger handler for both Folder Actions and file opens.
on maybe_open_calendar_item(item_reference)
	try
		set item_path to POSIX path of (item_reference as alias)
		
		ignoring case
			if item_path does not end with ".ics" then
				error number -128
			end if
		end ignoring
		
		set event_url to my google_calendar_url_for_file(item_path)
		
		open location event_url
	on error err_msg number err_num
		if err_num is not -128 then
			tell application "Finder" to activate
			display dialog "Could not open Google Calendar for this file:" & return & return & err_msg buttons {"OK"} default button "OK" with title app_title
		end if
	end try
end maybe_open_calendar_item

on google_calendar_url_for_file(item_path)
	set event_info to my parse_calendar_file(item_path)
	return my build_google_calendar_url(event_info)
end google_calendar_url_for_file

-- Read one .ics file and pull out the first VEVENT.
on parse_calendar_file(item_path)
	set file_contents to do shell script "/bin/cat " & quoted form of item_path
	set normalized_text to current application's NSString's stringWithString:file_contents
	set normalized_text to normalized_text's stringByReplacingOccurrencesOfString:("\r\n") withString:("\n")
	set normalized_text to normalized_text's stringByReplacingOccurrencesOfString:("\r") withString:("\n")
	set raw_lines to (normalized_text's componentsSeparatedByString:("\n")) as list
	set unfolded_lines to {}
	
	repeat with raw_line in raw_lines
		set line_text to raw_line as text
		if line_text starts with space or line_text starts with tab then
			if (count of unfolded_lines) > 0 then
				set last_line to item -1 of unfolded_lines
				set item -1 of unfolded_lines to last_line & text 2 thru -1 of line_text
			end if
		else
			set end of unfolded_lines to line_text
		end if
	end repeat
	
	set in_event to false
	set summary_text to ""
	set details_text to ""
	set location_text to ""
	set source_url to ""
	set start_info to missing value
	set end_info to missing value
	
	repeat with line_text in unfolded_lines
		set current_line to line_text as text
		set upper_line to my uppercase_text(current_line)
		
		if upper_line is "BEGIN:VEVENT" then
			set in_event to true
		else if upper_line is "END:VEVENT" then
			exit repeat
		else if in_event and current_line contains ":" then
			set separator_offset to offset of ":" in current_line
			set left_part to text 1 thru (separator_offset - 1) of current_line
			set value_text to text (separator_offset + 1) thru -1 of current_line
			set property_parts to my split_text(left_part, ";")
			set property_name to my uppercase_text(item 1 of property_parts)
			
			if property_name is "SUMMARY" and summary_text is "" then
				set summary_text to my unescape_ics_text(value_text)
			else if property_name is "DESCRIPTION" and details_text is "" then
				set details_text to my unescape_ics_text(value_text)
			else if property_name is "LOCATION" and location_text is "" then
				set location_text to my unescape_ics_text(value_text)
			else if property_name is "URL" and source_url is "" then
				set source_url to value_text
			else if property_name is "DTSTART" and start_info is missing value then
				set start_info to my parse_date_property(property_parts, value_text)
			else if property_name is "DTEND" and end_info is missing value then
				set end_info to my parse_date_property(property_parts, value_text)
			end if
		end if
	end repeat
	
	if start_info is missing value then error "The calendar event is missing DTSTART."
	if summary_text is "" then set summary_text to my basename_without_extension(item_path)
	
	return {summary_text:summary_text, details_text:details_text, location_text:location_text, source_url:source_url, start_info:start_info, end_info:end_info}
end parse_calendar_file

-- Turn DTSTART/DTEND style properties into Google Calendar date strings.
on parse_date_property(property_parts, value_text)
	set value_parameter to my uppercase_text(my parameter_value_from_parts(property_parts, "VALUE"))
	if value_parameter is "DATE" or my looks_like_date_only(value_text) then
		return {google_text:text 1 thru 8 of value_text, all_day:true, time_zone_name:"", uses_utc:false}
	end if
	
	set normalized_text to my normalize_datetime_value(value_text)
	if normalized_text ends with "Z" then
		return {google_text:normalized_text, all_day:false, time_zone_name:"", uses_utc:true}
	end if
	
	set raw_time_zone to my parameter_value_from_parts(property_parts, "TZID")
	set time_zone_name to my normalized_time_zone_name(raw_time_zone)
	return {google_text:normalized_text, all_day:false, time_zone_name:time_zone_name, uses_utc:false}
end parse_date_property

-- Build the only outbound URL used by this script.
on build_google_calendar_url(event_info)
	set start_info to start_info of event_info
	set end_info to end_info of event_info
	if end_info is missing value then set end_info to my default_end_for_start(start_info)
	
	set details_text to details_text of event_info
	set source_url to source_url of event_info
	if source_url is not "" then
		if details_text is "" then
			set details_text to source_url
		else if details_text does not contain source_url then
			set details_text to details_text & linefeed & linefeed & source_url
		end if
	end if
	
	set query_items to current application's NSMutableArray's alloc()'s init()
	(query_items's addObject:(current application's NSURLQueryItem's queryItemWithName:"action" value:"TEMPLATE"))
	(query_items's addObject:(current application's NSURLQueryItem's queryItemWithName:"text" value:(summary_text of event_info)))
	(query_items's addObject:(current application's NSURLQueryItem's queryItemWithName:"dates" value:((google_text of start_info) & "/" & (google_text of end_info))))
	
	if details_text is not "" then
		(query_items's addObject:(current application's NSURLQueryItem's queryItemWithName:"details" value:details_text))
	end if
	
	if (location_text of event_info) is not "" then
		(query_items's addObject:(current application's NSURLQueryItem's queryItemWithName:"location" value:(location_text of event_info)))
	end if
	
	if (all_day of start_info) is false and (uses_utc of start_info) is false and (time_zone_name of start_info) is not "" then
		(query_items's addObject:(current application's NSURLQueryItem's queryItemWithName:"ctz" value:(time_zone_name of start_info)))
	end if
	
	set url_components to current application's NSURLComponents's componentsWithString:"https://calendar.google.com/calendar/render"
	url_components's setQueryItems:query_items
	return (url_components's |URL|'s absoluteString()) as text
end build_google_calendar_url

on default_end_for_start(start_info)
	if all_day of start_info then
		return {google_text:my date_by_adding_interval((google_text of start_info), 86400, true, "", false), all_day:true, time_zone_name:"", uses_utc:false}
	end if
	
	return {google_text:my date_by_adding_interval((google_text of start_info), 3600, false, (time_zone_name of start_info), (uses_utc of start_info)), all_day:false, time_zone_name:(time_zone_name of start_info), uses_utc:(uses_utc of start_info)}
end default_end_for_start

on date_by_adding_interval(google_text, interval_seconds, is_all_day, time_zone_name, uses_utc)
	set formatter to current application's NSDateFormatter's alloc()'s init()
	formatter's setLocale:(current application's NSLocale's localeWithLocaleIdentifier:"en_US_POSIX")
	
	if is_all_day then
		formatter's setDateFormat:"yyyyMMdd"
		formatter's setTimeZone:(current application's NSTimeZone's timeZoneForSecondsFromGMT:0)
		set parsed_date to formatter's dateFromString:google_text
		if parsed_date is missing value then error "Could not parse all-day event date."
		set adjusted_date to parsed_date's dateByAddingTimeInterval:interval_seconds
		return (formatter's stringFromDate:adjusted_date) as text
	end if
	
	set working_text to google_text
	if uses_utc then set working_text to text 1 thru -2 of working_text
	formatter's setDateFormat:"yyyyMMdd'T'HHmmss"
	formatter's setTimeZone:(my foundation_time_zone(time_zone_name, uses_utc))
	set parsed_date to formatter's dateFromString:working_text
	if parsed_date is missing value then error "Could not parse event date and time."
	set adjusted_date to parsed_date's dateByAddingTimeInterval:interval_seconds
	if uses_utc then
		formatter's setTimeZone:(current application's NSTimeZone's timeZoneForSecondsFromGMT:0)
		return ((formatter's stringFromDate:adjusted_date) as text) & "Z"
	end if
	return (formatter's stringFromDate:adjusted_date) as text
end date_by_adding_interval

on foundation_time_zone(time_zone_name, uses_utc)
	if uses_utc then return current application's NSTimeZone's timeZoneForSecondsFromGMT:0
	if time_zone_name is not "" then
		set named_time_zone to current application's NSTimeZone's timeZoneWithName:time_zone_name
		if named_time_zone is not missing value then return named_time_zone
	end if
	return current application's NSTimeZone's localTimeZone()
end foundation_time_zone

on normalize_datetime_value(value_text)
	set normalized_text to value_text as text
	set has_utc_suffix to false
	
	if my uppercase_text(normalized_text) ends with "Z" then
		set has_utc_suffix to true
		set normalized_text to text 1 thru -2 of normalized_text
	end if
	
	if (length of normalized_text) is 13 then
		set normalized_text to normalized_text & "00"
	else if (length of normalized_text) is not 15 then
		error "Unsupported calendar date format: " & value_text
	end if
	
	if has_utc_suffix then return normalized_text & "Z"
	return normalized_text
end normalize_datetime_value

on looks_like_date_only(value_text)
	if (length of value_text) is not 8 then return false
	repeat with current_character in characters of value_text
		if "0123456789" does not contain (contents of current_character) then return false
	end repeat
	return true
end looks_like_date_only

on normalized_time_zone_name(raw_time_zone)
	set cleaned_time_zone to my trim_quotes(raw_time_zone)
	if cleaned_time_zone is "" then return ""
	if my time_zone_exists(cleaned_time_zone) then return cleaned_time_zone
	
	set time_zone_parts to my split_text(cleaned_time_zone, "/")
	if (count of time_zone_parts) ≥ 2 then
		set candidate_time_zone to (item -2 of time_zone_parts as text) & "/" & (item -1 of time_zone_parts as text)
		if my time_zone_exists(candidate_time_zone) then return candidate_time_zone
	end if
	
	return ""
end normalized_time_zone_name

on time_zone_exists(time_zone_name)
	return (current application's NSTimeZone's timeZoneWithName:time_zone_name) is not missing value
end time_zone_exists

on parameter_value_from_parts(property_parts, parameter_name)
	set parameter_prefix to my uppercase_text(parameter_name) & "="
	if (count of property_parts) < 2 then return ""
	repeat with property_part in items 2 thru -1 of property_parts
		set part_text to property_part as text
		if my uppercase_text(part_text) starts with parameter_prefix then
			return my trim_quotes(text ((length of parameter_prefix) + 1) thru -1 of part_text)
		end if
	end repeat
	return ""
end parameter_value_from_parts

on unescape_ics_text(value_text)
	set unescaped_text to current application's NSString's stringWithString:value_text
	set unescaped_text to unescaped_text's stringByReplacingOccurrencesOfString:("\\n") withString:(linefeed)
	set unescaped_text to unescaped_text's stringByReplacingOccurrencesOfString:("\\N") withString:(linefeed)
	set unescaped_text to unescaped_text's stringByReplacingOccurrencesOfString:("\\,") withString:(",")
	set unescaped_text to unescaped_text's stringByReplacingOccurrencesOfString:("\\;") withString:(";")
	set unescaped_text to unescaped_text's stringByReplacingOccurrencesOfString:("\\\\") withString:("\\")
	return unescaped_text as text
end unescape_ics_text

on uppercase_text(input_text)
	return ((current application's NSString's stringWithString:(input_text as text))'s uppercaseString()) as text
end uppercase_text

on split_text(input_text, delimiter_text)
	return ((current application's NSString's stringWithString:(input_text as text))'s componentsSeparatedByString:delimiter_text) as list
end split_text

on trim_quotes(input_text)
	set output_text to input_text as text
	if output_text starts with "\"" and output_text ends with "\"" and (length of output_text) ≥ 2 then
		return text 2 thru -2 of output_text
	end if
	return output_text
end trim_quotes

on basename_without_extension(item_path)
	set file_name to do shell script "/usr/bin/basename " & quoted form of item_path
	set dot_offset to offset of "." in file_name
	if dot_offset is 0 then return file_name
	return text 1 thru (dot_offset - 1) of file_name
end basename_without_extension
