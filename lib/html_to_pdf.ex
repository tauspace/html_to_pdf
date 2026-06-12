defmodule HtmlToPdf do
  @moduledoc """
  Converts HTML to PDF via a Gotenberg instance.

  Configure the Gotenberg base URL with the `GOTENBERG_URL` environment variable.
  """

  @doc """
  Generates a PDF from HTML content.

  Sends the HTML to Gotenberg's Chromium HTML-to-PDF endpoint and returns the
  raw PDF binary on success.

  ## Parameters
  - `html` - binary containing HTML content
  - `opts` - keyword list of options:
    - `:generate_file` - when `true`, writes the PDF to a temp file and
      returns `{:ok, path}` instead of `{:ok, binary}`. Defaults to `false`.

  ## Returns
  - `{:ok, pdf_binary}` on success (default)
  - `{:ok, path}` when `generate_file: true`
  - `{:error, {:non_inline_image_src, src}}` if an img tag has a non-data-URI src
  - `{:error, {status_code, body}}` on a non-200 HTTP response
  - `{:error, reason}` on a request or file-write failure
  """
  def generate_pdf(html, opts \\ []) do
    with :ok <- validate_image_srcs(html),
         {:ok, pdf} <- generate_pdf_request(html) do
      if Keyword.get(opts, :generate_file, false) do
        write_temp_file(pdf)
      else
        {:ok, pdf}
      end
    end
  end

  defp generate_pdf_request(html) do
    url = System.fetch_env!("GOTENBERG_URL") <> "/forms/chromium/convert/html"
    boundary = "----FormBoundary" <> (:crypto.strong_rand_bytes(8) |> Base.encode16())

    body = build_multipart(html, boundary)

    headers = [
      {"content-type", "multipart/form-data; boundary=#{boundary}"}
    ]

    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, HtmlToPdf.Finch) do
      {:ok, %Finch.Response{status: 200, body: pdf}} ->
        {:ok, pdf}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_temp_file(pdf) do
    filename = "html_to_pdf_#{:erlang.unique_integer([:positive, :monotonic])}.pdf"
    path = Path.join(System.tmp_dir!(), filename)

    case File.write(path, pdf) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  # Matches src="..." or src='...' inside any <img> tag.
  @img_src_re ~r/<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["']/i

  defp validate_image_srcs(html) do
    invalid =
      @img_src_re
      |> Regex.scan(html, capture: :all_but_first)
      |> List.flatten()
      |> Enum.find(&(not String.starts_with?(&1, "data:")))

    case invalid do
      nil -> :ok
      src -> {:error, {:non_inline_image_src, src}}
    end
  end

  defp build_multipart(html, boundary) do
    IO.iodata_to_binary([
      "--", boundary, "\r\n",
      "Content-Disposition: form-data; name=\"files\"; filename=\"index.html\"\r\n",
      "Content-Type: text/html\r\n",
      "\r\n",
      html, "\r\n",
      "--", boundary, "--\r\n"
    ])
  end
end
