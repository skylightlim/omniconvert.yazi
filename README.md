# omniconvert.yazi

A FileConverter-style conversion menu for [yazi](https://github.com/sxyazi/yazi).

Hover a file (or select several), press `c z`, and a menu appears listing **only
the formats those files can actually become**. Pick one with a single keypress.

```
 ╭ Convert ─────────────────────────────╮
 │ j   .jpg   JPEG — photos             │
 │ w   .webp  WebP — small, web         │
 │ a   .avif  AVIF — smallest           │
 │ d   .pdf   PDF — document            │
 │ M   .pdf   Merge all selected …      │
 ╰──────────────────────────────────────╯
```

This is the same idea as [File Converter](https://github.com/Tichau/FileConverter)
on Windows and [flyingmouse-format](https://github.com/LaoFeng-mouse/flyingmouse-format):
a right-click menu of valid targets, rather than a command line to remember.

## Install

Two steps: the plugin, then the converter script it drives.

```sh
ya pkg add skylightlim/omniconvert
```

That installs the plugin and drops the `omniconvert` script alongside it. Put the
script on your `PATH`:

```sh
ln -s ~/.config/yazi/plugins/omniconvert.yazi/omniconvert ~/.local/bin/omniconvert
```

Then bind the menu in `~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on   = [ "c", "z" ]
run  = "plugin omniconvert"
desc = "Convert to… (menu)"
```

<details>
<summary>Without <code>ya pkg</code></summary>

```sh
git clone https://github.com/skylightlim/omniconvert.yazi \
  ~/.config/yazi/plugins/omniconvert.yazi
ln -s ~/.config/yazi/plugins/omniconvert.yazi/omniconvert ~/.local/bin/omniconvert
```

</details>

## How it works

Two pieces:

| Piece | Job |
| --- | --- |
| `main.lua` | The menu. Asks the script what is possible, then runs it. |
| `omniconvert` | A bash script that does the conversion. Useful on its own, with no yazi involved. |

The menu is not hardcoded. It calls `omniconvert targets <files>` and builds itself
from the answer, so the menu can never offer a conversion the backend can't do.
With several files selected it shows the **intersection** — only formats every
selected file can reach.

## Keys

| Key | Action |
| --- | --- |
| `c z` | Open the convert menu |

That is the only binding, deliberately: pressing `c` on its own shows no formats,
and every format lives inside the menu behind `c z`.

If you want a no-menu shortcut for something you convert constantly, put it
behind its own prefix rather than directly under `c`, so `c` stays clean:

```toml
[[mgr.prepend_keymap]]
on   = [ "c", "Z", "4" ]
run  = "plugin omniconvert -- mp4"
desc = "Convert → MP4 (no menu)"
```

Any format the backend supports works as `plugin omniconvert -- <ext>`, plus
`pdfmerge` for merging images into one PDF.

## What converts to what

| From | To |
| --- | --- |
| Images (png jpg webp avif heic jxl gif bmp tiff tga ico svg psd + camera RAW) | png jpg webp avif heic jxl gif bmp tiff tga ico pdf |
| PDF | png jpg webp avif tiff (one image per page) |
| Audio | mp3 opus aac m4a flac wav ogg wma |
| Video | mp4 webm mkv mov avi flv wmv gif — **or** any audio format, to pull out the soundtrack |
| doc docx odt rtf txt md | pdf docx odt rtf txt html |
| html htm | pdf odt txt |
| xls xlsx ods csv tsv | pdf xlsx ods csv |
| ppt pptx odp | pdf pptx odp |

Run `omniconvert list` for the current list, or `omniconvert targets myfile.png` to ask
about one file.

Document conversions are grouped by LibreOffice module because each module
exports a different set — a Writer file reaches `docx`, an HTML file (which
LibreOffice opens as Writer/Web) does not.

## Nothing is ever overwritten

`photo.png → photo.webp`, and if `photo.webp` already exists you get
`photo-2.webp`. Originals are always left alone.

## Requirements

| Tool | Needed for |
| --- | --- |
| `imagemagick` | images, image→pdf |
| `ffmpeg` | audio and video |
| `libreoffice` | documents |
| `poppler` (`pdftoppm`, `pdfinfo`) | pdf→images |
| `ghostscript` | pdf→webp/avif |

You only need the ones covering the formats you actually use — the menu offers
whatever is installed and reports clearly when a tool is missing.

```sh
# Arch
sudo pacman -S imagemagick ffmpeg libreoffice-fresh poppler ghostscript
# Debian/Ubuntu
sudo apt install imagemagick ffmpeg libreoffice poppler-utils ghostscript
# Fedora
sudo dnf install ImageMagick ffmpeg libreoffice poppler-utils ghostscript
# macOS
brew install imagemagick ffmpeg poppler ghostscript && brew install --cask libreoffice
```

## Tuning quality

Environment variables, with defaults:

```sh
JPG_QUALITY=90  WEBP_QUALITY=85  AVIF_QUALITY=55  HEIC_QUALITY=80
PDF_DPI=200     GIF_FPS=12       GIF_WIDTH=720
MP3_VBR=2       VIDEO_CRF=23
```

Set them in your shell profile to change the defaults, or per run:

```sh
WEBP_QUALITY=95 omniconvert webp *.png
```

## Using it outside yazi

```sh
omniconvert webp photo.png            # one file
omniconvert mp3 *.flac                # batch
omniconvert m4a podcast.mp4           # extract audio from video
omniconvert pdf report.docx           # document → pdf
omniconvert docx notes.md             # markdown → word
omniconvert jpg scan.pdf              # pdf pages → jpgs
omniconvert pdf --merge *.jpg         # many images → ONE pdf
omniconvert targets photo.png         # what can this become?
omniconvert list                      # everything supported
```

When run without a terminal and outside yazi it logs to
`~/.local/state/omniconvert.log` and sends a desktop notification.

## License

MIT — see [LICENSE](LICENSE).
