# Dot-source from Setup-ExternalTools.ps1. Edit URLs when upgrading pinned builds.
@{
    # ImageMagick portable (ZIP; Expand-Archive で展開)
    ImageMagickZipUrl      = 'https://imagemagick.org/archive/binaries/ImageMagick-7.1.2-12-portable-Q16-HDRI-x64.zip'
    ImageMagickExtractDir  = 'ImageMagick-portable-Q16-HDRI-x64'

    # Ghostscript Windows x64 インストーラ（サイレント後に Program Files から ImageMagick フォルダへコピー）
    GhostscriptInstallerUrl = 'https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10051/gs10051w64.exe'

    QpdfZipUrl             = 'https://github.com/qpdf/qpdf/releases/download/v11.9.1/qpdf-11.9.1-msvc64.zip'
    QpdfInnerTopDir        = 'qpdf-11.9.1-msvc64'

    ExifToolZipUrl         = 'https://exiftool.org/exiftool-13.30_64.zip'
    ExifToolExtractDir     = 'exiftool-13.30_64'

    PdfcpuZipUrl           = 'https://github.com/pdfcpu/pdfcpu/releases/download/v0.11.0/pdfcpu_0.11.0_Windows_x86_64.zip'

    RealEsrganRepoUrl      = 'https://github.com/xinntao/Real-ESRGAN.git'
    RealEsrganCommit       = 'a4abfb2979a7bbff3f69f58f58ae324608821e27'
    RealEsrganWeightsUrl   = 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth'

    # PyTorch: 環境に合わせて Setup-ExternalTools.ps1 の -TorchIndexUrl を変更
    TorchIndexUrlDefault   = 'https://download.pytorch.org/whl/nightly/cu128'

    YomitokuPipSpec        = 'yomitoku==0.10.3'

    TessdataEngUrl         = 'https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata'
    TessdataJpnUrl         = 'https://github.com/tesseract-ocr/tessdata_best/raw/main/jpn.traineddata'
}
