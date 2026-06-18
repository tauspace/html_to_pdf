defmodule HtmlToPdfTest do
  use ExUnit.Case

  @gotenberg_demo "https://demo.gotenberg.dev"

  # 1x1 transparent GIF as a data URI
  @data_uri_img "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"

  describe "generate_pdf/2" do
    test "converts HTML to a PDF binary using the Gotenberg demo server" do
      html = """
      <!DOCTYPE html>
      <html>
        <head><meta charset="utf-8" /></head>
        <body><h1>Hello from HtmlToPdf</h1></body>
      </html>
      """

      System.put_env("GOTENBERG_URL", @gotenberg_demo)

      assert {:ok, pdf} = HtmlToPdf.generate_pdf(html)
      assert binary_part(pdf, 0, 5) == "%PDF-"
    end

    test "accepts img tags with data URI src" do
      html = """
      <!DOCTYPE html>
      <html>
        <body><img src="#{@data_uri_img}" alt="test" /></body>
      </html>
      """

      System.put_env("GOTENBERG_URL", @gotenberg_demo)

      assert {:ok, pdf} = HtmlToPdf.generate_pdf(html)
      assert binary_part(pdf, 0, 5) == "%PDF-"
    end

    test "rejects img with https src" do
      html = ~s(<img src="https://example.com/image.png" />)

      assert {:error, {:non_inline_image_src, "https://example.com/image.png"}} =
               HtmlToPdf.generate_pdf(html)
    end

    test "rejects img with http src" do
      html = ~s(<img src="http://example.com/image.png" />)

      assert {:error, {:non_inline_image_src, "http://example.com/image.png"}} =
               HtmlToPdf.generate_pdf(html)
    end

    test "rejects img with relative path src" do
      html = ~s(<img src="images/photo.jpg" />)

      assert {:error, {:non_inline_image_src, "images/photo.jpg"}} =
               HtmlToPdf.generate_pdf(html)
    end

    test "rejects first offending src when multiple non-inline images are present" do
      html = """
      <img src="images/first.png" />
      <img src="https://example.com/second.png" />
      """

      assert {:error, {:non_inline_image_src, "images/first.png"}} =
               HtmlToPdf.generate_pdf(html)
    end

    test "rejects non-inline src in single-quoted attribute" do
      html = ~s(<img src='images/photo.jpg' />)

      assert {:error, {:non_inline_image_src, "images/photo.jpg"}} =
               HtmlToPdf.generate_pdf(html)
    end

    test "generate_file: true writes PDF to a temp file and returns its path" do
      data_uri = red_png_data_uri(50, 50)

      html = """
      <!DOCTYPE html>
      <html>
        <head><meta charset="utf-8" /></head>
        <body>
          <h1>PDF with embedded image</h1>
          <img src="#{data_uri}" alt="red square" style="width:200px;height:200px;display:block;" />
          <p>The red square above is a PNG embedded as a base64 data URI.</p>
        </body>
      </html>
      """

      System.put_env("GOTENBERG_URL", @gotenberg_demo)

      assert {:ok, path} = HtmlToPdf.generate_pdf(html, generate_file: true)

      assert Path.extname(path) == ".pdf"
      assert File.exists?(path)
      assert {:ok, content} = File.read(path)
      assert binary_part(content, 0, 5) == "%PDF-"

      IO.puts("\nGenerated PDF saved to: #{path}")
    end
  end

  describe "GOTENBERG_TIMEOUT" do
    test "returns an error when the request exceeds the configured timeout" do
      {:ok, listen_socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
      {:ok, {_, port}} = :inet.sockname(listen_socket)

      on_exit(fn ->
        :gen_tcp.close(listen_socket)
        System.delete_env("GOTENBERG_TIMEOUT")
      end)

      # Accept the connection but never send a response, simulating a hung server.
      Task.start(fn ->
        case :gen_tcp.accept(listen_socket, 5_000) do
          {:ok, _conn} -> Process.sleep(:infinity)
          _ -> :ok
        end
      end)

      System.put_env("GOTENBERG_URL", "http://localhost:#{port}")
      System.put_env("GOTENBERG_TIMEOUT", "200")

      assert {:error, _reason} = HtmlToPdf.generate_pdf("<html><body>timeout</body></html>")
    end
  end

  # Builds a solid-colour PNG of the given dimensions using raw Elixir/OTP — no
  # external library needed. Each scanline is a filter-0 row of RGB pixels.
  defp red_png_data_uri(width, height) do
    sig = <<137, 80, 78, 71, 13, 10, 26, 10>>

    ihdr_data = <<width::32, height::32, 8, 2, 0, 0, 0>>

    # filter byte (None=0) followed by one red pixel per column
    row = <<0>> <> :binary.copy(<<255, 0, 0>>, width)
    raw_data = :binary.copy(row, height)

    png =
      sig <>
        png_chunk("IHDR", ihdr_data) <>
        png_chunk("IDAT", :zlib.compress(raw_data)) <>
        png_chunk("IEND", <<>>)

    "data:image/png;base64," <> Base.encode64(png)
  end

  defp png_chunk(type, data) do
    crc = :erlang.crc32(<<type::binary, data::binary>>)
    <<byte_size(data)::32, type::binary, data::binary, crc::32>>
  end
end
