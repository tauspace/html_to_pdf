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

    test "rejects img tags with http src" do
      html = ~s(<img src="http://example.com/image.png" />)

      assert {:error, {:external_image_src, "http://example.com/image.png"}} =
               HtmlToPdf.generate_pdf(html)
    end

    test "rejects img tags with https src" do
      html = ~s(<img src="https://example.com/image.png" />)

      assert {:error, {:external_image_src, "https://example.com/image.png"}} =
               HtmlToPdf.generate_pdf(html)
    end

    test "rejects first offending URL when multiple external images are present" do
      html = """
      <img src="https://a.com/one.png" />
      <img src="https://b.com/two.png" />
      """

      assert {:error, {:external_image_src, "https://a.com/one.png"}} =
               HtmlToPdf.generate_pdf(html)
    end

    test "rejects external src in single-quoted attribute" do
      html = ~s(<img src='https://example.com/image.png' />)

      assert {:error, {:external_image_src, "https://example.com/image.png"}} =
               HtmlToPdf.generate_pdf(html)
    end
  end
end
