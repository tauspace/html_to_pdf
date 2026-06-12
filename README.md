# HtmlToPdf

Converts HTML to PDF by sending it to a [Gotenberg](https://gotenberg.dev) instance via its Chromium HTML-to-PDF API. Uses [Finch](https://github.com/sneako/finch) for HTTP.

## Installation

This library is not published on Hex. Add it as a Git dependency in your `mix.exs`:

```elixir
def deps do
  [
    {:html_to_pdf, github: "tauspace/html_to_pdf"}
  ]
end
```

To pin to a specific commit (recommended for production):

```elixir
{:html_to_pdf, github: "tauspace/html_to_pdf", ref: "bbe08a0"}
```

Then fetch dependencies:

```bash
mix deps.get
```

## Requirements

A running Gotenberg instance. The quickest way is Docker:

```bash
docker run --rm -p 3000:3000 gotenberg/gotenberg:8
```

## Configuration

Set the `GOTENBERG_URL` environment variable to the base URL of your Gotenberg instance:

```bash
export GOTENBERG_URL=http://localhost:3000
```

## Usage

### Basic — return PDF binary

```elixir
html = """
<!DOCTYPE html>
<html>
  <head><meta charset="utf-8" /></head>
  <body><h1>Hello, PDF!</h1></body>
</html>
"""

{:ok, pdf_binary} = HtmlToPdf.generate_pdf(html)
```

### Write PDF to a temp file

Pass `generate_file: true` to write the result to a file under the system temp directory. The returned path can be opened directly in a PDF viewer.

```elixir
{:ok, path} = HtmlToPdf.generate_pdf(html, generate_file: true)
# => {:ok, "/tmp/html_to_pdf_123.pdf"}
```

### Embedding images

All `<img>` tags **must** use base64 data URIs. External URLs and relative file paths are rejected with `{:error, {:non_inline_image_src, src}}`.

```elixir
# Encode an image file to a data URI
image_data = File.read!("photo.jpg") |> Base.encode64()
data_uri   = "data:image/jpeg;base64,#{image_data}"

html = """
<!DOCTYPE html>
<html>
  <body>
    <img src="#{data_uri}" alt="photo" />
  </body>
</html>
"""

{:ok, path} = HtmlToPdf.generate_pdf(html, generate_file: true)
```

## Options

| Option          | Type    | Default | Description                                                                 |
|-----------------|---------|---------|-----------------------------------------------------------------------------|
| `generate_file` | boolean | `false` | When `true`, writes the PDF to a temp file and returns `{:ok, path}`.      |

## Return values

| Result                                      | Meaning                                              |
|---------------------------------------------|------------------------------------------------------|
| `{:ok, binary}`                             | PDF content as a binary (default)                    |
| `{:ok, path}`                               | Path to the written temp file (`generate_file: true`)|
| `{:error, {:non_inline_image_src, src}}`    | An `<img>` tag contains a non-data-URI `src`         |
| `{:error, {status_code, body}}`             | Gotenberg returned a non-200 response                |
| `{:error, reason}`                          | HTTP request or file write failed                    |
