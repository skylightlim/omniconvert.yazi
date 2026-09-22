--- omniconvert.yazi — FileConverter-style conversion menu for yazi.
---
--- Press the keybinding on a hovered or selected file and a menu appears
--- listing only the formats that file can actually become. The list comes
--- from `omniconvert targets`, so the menu can never offer a conversion the
--- backend cannot perform.
---
---   plugin omniconvert            -- open the menu (the normal way to use this)
---   plugin omniconvert -- webp    -- skip the menu, convert straight to .webp
---   plugin omniconvert -- md      -- straight to Markdown (bound to `c Z m`)

-- Single-keypress mnemonic per format. Keys only have to be unique within one
-- menu, so `o` can be Opus for audio and ODT for documents.
local KEYS = {
	-- images
	png = "p", jpg = "j", webp = "w", avif = "a", heic = "h", jxl = "x",
	gif = "g", bmp = "b", tiff = "t", tga = "T", ico = "i", pdf = "d",
	-- audio
	mp3 = "3", opus = "o", aac = "c", m4a = "m", flac = "f", wav = "s",
	ogg = "O", wma = "W",
	-- video
	mp4 = "4", webm = "e", mkv = "k", mov = "v", avi = "A", flv = "F", wmv = "V",
	-- documents
	docx = "D", odt = "o", rtf = "r", txt = "t", html = "h",
	xlsx = "x", ods = "s", csv = "C", pptx = "p", odp = "P",
	-- `m` is M4A above too, which is safe: no input reaches both. Markdown is
	-- offered for documents, PDFs and images, M4A only for audio and video.
	md = "m",
}

local LABELS = {
	png = "PNG — lossless",        jpg = "JPEG — photos",
	webp = "WebP — small, web",    avif = "AVIF — smallest",
	heic = "HEIC — Apple",         jxl = "JPEG XL",
	gif = "GIF — animation",       bmp = "BMP — uncompressed",
	tiff = "TIFF — print/scan",    tga = "TGA",
	ico = "ICO — Windows icon",    pdf = "PDF — document",
	mp3 = "MP3 — plays anywhere",  opus = "Opus — best at small sizes",
	aac = "AAC",                   m4a = "M4A — Apple",
	flac = "FLAC — lossless",      wav = "WAV — uncompressed",
	ogg = "OGG Vorbis",            wma = "WMA — Windows",
	mp4 = "MP4 — H.264, universal", webm = "WebM — VP9",
	mkv = "MKV — Matroska",        mov = "MOV — QuickTime",
	avi = "AVI — legacy",          flv = "FLV — legacy",
	wmv = "WMV — Windows",
	docx = "DOCX — Word",          odt = "ODT — LibreOffice Writer",
	rtf = "RTF — rich text",       txt = "TXT — plain text",
	html = "HTML — web page",      xlsx = "XLSX — Excel",
	ods = "ODS — LibreOffice Calc", csv = "CSV — plain table",
	pptx = "PPTX — PowerPoint",    odp = "ODP — LibreOffice Impress",
	md = "Markdown — portable text",
}

-- Keys handed out to a format the tables above don't know about, so a format
-- added to the backend still shows up in the menu.
local SPARE_KEYS = "123456789qyzunlGHIJKLNQRSUXYZ"

local AUDIO_OUT = {
	mp3 = true, opus = true, aac = true, m4a = true,
	flac = true, wav = true, ogg = true, wma = true,
}
local IMAGE_EXT = {
	bmp = true, gif = true, jpg = true, jpeg = true, png = true, tif = true,
	tiff = true, tga = true, webp = true, avif = true, heic = true, heif = true,
	jxl = true, ico = true, svg = true, psd = true,
}
local VIDEO_EXT = {
	mp4 = true, m4v = true, mkv = true, webm = true, mov = true, avi = true,
	flv = true, wmv = true, mpg = true, mpeg = true, vob = true, ts = true,
	["3gp"] = true, ["3g2"] = true, ogv = true, mts = true, m2ts = true, f4v = true,
}

local function info(content, level)
	ya.notify { title = "Omniconvert", content = content, level = level or "info", timeout = 5 }
end

local selected_or_hovered = ya.sync(function()
	local tab, paths = cx.active, {}
	for _, u in pairs(tab.selected) do
		paths[#paths + 1] = tostring(u)
	end
	if #paths == 0 and tab.current.hovered then
		paths[1] = tostring(tab.current.hovered.url)
	end
	return paths
end)

local function ext_of(path)
	local base = path:match("[^/]+$") or path
	local e = base:match("^.+%.([^.]+)$")
	return e and e:lower() or ""
end

local function last_lines(s, n)
	local lines, out = {}, {}
	for line in s:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
	local first = math.max(1, #lines - n + 1)
	for i = first, #lines do out[#out + 1] = lines[i] end
	return table.concat(out, "\n")
end

--- Ask the backend which formats every one of `paths` can become.
--- Returns a list of extensions, or nil plus an error message.
local function valid_targets(paths)
	local cmd = Command("omniconvert"):arg("targets")
	for _, p in ipairs(paths) do cmd = cmd:arg(p) end

	local output, err = cmd:output()
	if not output then
		return nil, "Could not run omniconvert: " .. tostring(err)
	end
	if not output.status.success then
		return {} -- no shared target format
	end

	local targets = {}
	for line in output.stdout:gmatch("[^\r\n]+") do
		local t = line:match("^%s*(%S+)%s*$")
		if t then targets[#targets + 1] = t end
	end
	return targets
end

--- Turn the target list into ya.which candidates, keeping keys unique.
local function build_cands(targets, src_ext, merge_ok)
	local cands, taken, spare = {}, {}, 1
	local from_video = VIDEO_EXT[src_ext] or false

	local function claim(preferred)
		if preferred and not taken[preferred] then
			taken[preferred] = true
			return preferred
		end
		while spare <= #SPARE_KEYS do
			local k = SPARE_KEYS:sub(spare, spare)
			spare = spare + 1
			if not taken[k] then
				taken[k] = true
				return k
			end
		end
		return nil
	end

	-- Markdown is what this is reached for most, so it leads the menu and claims
	-- `m` before anything else can, whatever order the backend printed.
	local ordered = {}
	for _, t in ipairs(targets) do
		if t == "md" then
			table.insert(ordered, 1, t)
		else
			ordered[#ordered + 1] = t
		end
	end

	for _, t in ipairs(ordered) do
		local key = claim(KEYS[t])
		if key then
			local desc = LABELS[t] or t:upper()
			if from_video and AUDIO_OUT[t] then
				desc = desc .. "  (extract audio)"
			end
			cands[#cands + 1] = {
				on = key,
				desc = string.format(".%-5s %s", t, desc),
				target = t,
			}
		end
	end

	if merge_ok then
		local key = claim("M")
		if key then
			cands[#cands + 1] = {
				on = key,
				desc = ".pdf   Merge all selected images into ONE PDF",
				target = "pdf",
				merge = true,
			}
		end
	end
	return cands
end

local function run_conversion(paths, target, merge)
	local cmd = Command("omniconvert"):arg(target)
	if merge then cmd = cmd:arg("--merge") end
	for _, p in ipairs(paths) do cmd = cmd:arg(p) end

	local output, err = cmd:env("OMNICONVERT_NO_LOG", "1"):output()
	if not output then
		info("Could not run omniconvert: " .. tostring(err), "error")
		return
	end

	if output.status.success then
		local msg = last_lines(output.stdout, 3)
		info(msg ~= "" and msg or ("Converted %d file(s) to .%s"):format(#paths, target))
	else
		local msg = last_lines(output.stdout .. "\n" .. output.stderr, 8)
		info(msg ~= "" and msg or "Conversion failed", "error")
	end
end

return {
	entry = function(_, job)
		ya.emit("escape", { visual = true })

		local paths = selected_or_hovered()
		if #paths == 0 then
			return info("Nothing hovered or selected", "error")
		end

		-- Direct mode: `plugin omniconvert -- webp` converts without a menu.
		local direct = job.args and (job.args[1] or job.args.extension)
		if direct and direct ~= "" then
			direct = tostring(direct):lower():gsub("^%.", "")
			if direct == "pdfmerge" then
				return run_conversion(paths, "pdf", true)
			end
			return run_conversion(paths, direct, false)
		end

		-- Menu mode: offer only what these files can actually become.
		local targets, err = valid_targets(paths)
		if not targets then
			return info(err, "error")
		end
		if #targets == 0 then
			local what = #paths == 1
				and ("Nothing can be converted from ." .. ext_of(paths[1]))
				or "The selected files share no common target format"
			return info(what .. " — mix of types?", "warn")
		end

		local src_ext = ext_of(paths[1])
		local all_images = true
		for _, p in ipairs(paths) do
			if not IMAGE_EXT[ext_of(p)] then
				all_images = false
				break
			end
		end

		local cands = build_cands(targets, src_ext, all_images and #paths > 1)
		local idx = ya.which { cands = cands }
		if not idx then
			return -- user cancelled
		end

		local pick = cands[idx]
		local noun = #paths == 1 and "file" or ("%d files"):format(#paths)
		info(("Converting %s → .%s …"):format(noun, pick.target))
		run_conversion(paths, pick.target, pick.merge)
	end,
}
