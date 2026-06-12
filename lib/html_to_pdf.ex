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
  - `_opts` - options (reserved for future use)

  ## Returns
  - `{:ok, pdf_binary}` on success
  - `{:error, {status_code, body}}` on a non-200 HTTP response
  - `{:error, reason}` on a request failure
  """
  def generate_pdf(html, _opts \\ []) do
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
