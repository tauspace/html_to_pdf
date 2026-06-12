defmodule HtmlToPdfTest do
  use ExUnit.Case

  @gotenberg_demo "https://demo.gotenberg.dev"

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

      # PDF files start with the %PDF- header
      assert binary_part(pdf, 0, 5) == "%PDF-"
    end
  end
end
