# omniconvert.yazi

A FileConverter-style conversion menu for [yazi](https://github.com/sxyazi/yazi).

Hover a file (or select several), press `c z`, and a menu appears listing **only
the formats those files can actually become**. Pick one with a single keypress.

```
 ╭ Convert ─────────────────────────────╮
 │ m   .md    Markdown — portable text  │
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

Two pieces to install: the plugin, and the `omniconvert` script that does the
converting.

```sh
ya pkg add skylightlim/omniconvert

mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/skylightlim/omniconvert.yazi/main/omniconvert \
  -o ~/.local/bin/omniconvert && chmod +x ~/.local/bin/omniconvert
```

The second command is not optional. `ya pkg` only deploys a plugin's Lua, README
and LICENSE, so it does not carry the script across — and the plugin is only a
menu without it. Make sure `~/.local/bin` is on your `PATH`.

<details>
<summary>Or clone, which gets both at once</summary>

```sh
git clone https://github.com/skylightlim/omniconvert.yazi \
  ~/.config/yazi/plugins/omniconvert.yazi
ln -s ~/.config/yazi/plugins/omniconvert.yazi/omniconvert ~/.local/bin/omniconvert
```

A symlink means `git pull` updates the plugin and the script together. You give up
`ya pkg upgrade` for this plugin, which will not touch a directory it did not
deploy.

</details>

Then bind the menu in `~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on   = [ "c", "z" ]
run  = "plugin omniconvert"
desc = "Convert to… (menu)"
```

Check it landed:

```sh
omniconvert list
```

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
| `c Z m` | Convert straight to Markdown, no menu |

`c z` is the only *menu* binding, deliberately: pressing `c` on its own shows no formats,
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
| doc docx odt rtf txt md | pdf docx odt rtf txt html **md** |
| html htm | pdf odt txt **md** |
| xls xlsx ods csv tsv | pdf xlsx ods csv **md** |
| ppt pptx odp | pdf pptx odp **md** |

Images and PDFs reach **md** too — see below.

Run `omniconvert list` for the current list, or `omniconvert targets myfile.png` to ask
about one file.

Document conversions are grouped by LibreOffice module because each module
exports a different set — a Writer file reaches `docx`, an HTML file (which
LibreOffice opens as Writer/Web) does not.

## Anything → Markdown

`.md` is offered for every document, spreadsheet, deck, PDF and image, and it is
the one target that takes a different route for each of them:

| From | Route |
| --- | --- |
| `doc docx odt rtf txt` | LibreOffice, which has exported Markdown since 26.8 |
| `html htm` | markitdown — LibreOffice opens HTML as Writer/Web, which has no Markdown export |
| `xls xlsx csv tsv`, `ppt pptx` | markitdown |
| `ods odp` | LibreOffice → `xlsx`/`pptx` → markitdown, since neither tool covers OpenDocument alone |
| PDF **with** a text layer | `pdftotext -layout` |
| PDF **without** one, and images | OCR, with tesseract |

So Word documents convert with LibreOffice alone. markitdown is only needed for
spreadsheets, decks and HTML; tesseract only for scans and images.

**OCR runs only when it has to.** A PDF is checked for a text layer first and is
rasterised and OCR'd only if it hasn't got one, which keeps an ordinary PDF under
a tenth of a second. Either route separates pages with `## Page N` headings.

Expect text, not structure: OCR recovers the words on a scan, not its tables. An
image with no readable text produces an empty `.md`.

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
| `markitdown` | spreadsheets, decks and html → md |
| `tesseract` | OCR, for scanned pdfs and images → md |

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

For Markdown, add markitdown (a Python tool, so install it isolated) and, if you
want OCR, tesseract with the languages you read:

```sh
uv tool install 'markitdown[pptx,xlsx,xls]'    # or: pipx install 'markitdown[pptx,xlsx,xls]'

sudo pacman -S tesseract tesseract-data-eng tesseract-data-chi_sim   # Arch
sudo apt install tesseract-ocr tesseract-ocr-chi-sim                 # Debian/Ubuntu
brew install tesseract tesseract-lang                                # macOS
```

The `pdf` extra is deliberately absent: PDFs go through poppler and tesseract,
which handle them better here than markitdown's PDF path does.

## Tuning quality

Environment variables, with defaults:

```sh
JPG_QUALITY=90  WEBP_QUALITY=85  AVIF_QUALITY=55  HEIC_QUALITY=80
PDF_DPI=200     GIF_FPS=12       GIF_WIDTH=720
MP3_VBR=2       VIDEO_CRF=23
OCR_DPI=300     PDF_TEXT_MIN=64
```

`PDF_TEXT_MIN` is how many characters of text layer a PDF needs before it counts
as born-digital rather than a scan. `OMNICONVERT_OCR_LANG` overrides the OCR
language, which is otherwise `eng`, or `eng+chi_sim` when the Chinese data is
installed — tesseract has no autodetect, so a language it was not given is a
language it cannot read.

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
omniconvert md report.xlsx            # spreadsheet → markdown table
omniconvert md slides.pptx            # deck → markdown
omniconvert md scan.pdf               # scanned pdf → OCR'd markdown
omniconvert md *.docx                 # batch
omniconvert jpg scan.pdf              # pdf pages → jpgs
omniconvert pdf --merge *.jpg         # many images → ONE pdf
omniconvert targets photo.png         # what can this become?
omniconvert list                      # everything supported
```

When run without a terminal and outside yazi it logs to
`~/.local/state/omniconvert.log` and sends a desktop notification.

## License

MIT — see [LICENSE](LICENSE).
