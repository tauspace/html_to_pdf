defmodule HtmlToPdfTest do
  use ExUnit.Case

  @gotenberg_demo "https://demo.gotenberg.dev"

  # 1x1 transparent GIF as a data URI
  @data_uri_img "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"

  # 10x10 red PNG as a data URI
  @data_uri_png "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mP8z8BQDwADhQGAWjR9awAAAABJRU5ErkJggg=="

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
      html = """
      <!DOCTYPE html>
      <html>
        <head><meta charset="utf-8" /></head>
        <body>
          <h1>PDF with embedded image</h1>
          <img src="#{@data_uri_png}" alt="red square" style="width:100px;height:100px;" />
          <p>The image above is embedded as a base64 data URI.</p>
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
end
