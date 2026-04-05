#pragma warning disable CA2235 // Mark all non-serializable fields

using System;
using System.Buffers;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
using System.Runtime.CompilerServices;
using System.Diagnostics.CodeAnalysis;
using System.Runtime.Serialization;

using IPA.Cores.Basic;
using IPA.Cores.Helper.Basic;
using static IPA.Cores.Globals.Basic;

using IPA.Cores.Codes;
using IPA.Cores.Helper.Codes;
using static IPA.Cores.Globals.Codes;

using SuperBookTools;
using SuperBookTools.App;

namespace SuperBookTools.App
{
    public static class SuperBookExternalTools
    {
        public static readonly ImageMagickUtil ImageMagick = new ImageMagickUtil(new ImageMagickOptions(
            Path.Combine(Env.AppRootDir, @"..\external_tools\external_tools\image_tools\ImageMagick-portable-Q16-HDRI-x64\magick.exe"),
            Path.Combine(Env.AppRootDir, @"..\external_tools\external_tools\image_tools\ImageMagick-portable-Q16-HDRI-x64\mogrify.exe"),
            Path.Combine(Env.AppRootDir, @"..\external_tools\external_tools\image_tools\exiftool-13.30_64\exiftool.exe"),
            Path.Combine(Env.AppRootDir, @"..\external_tools\external_tools\image_tools\QPDF\bin\qpdf.exe"),
            Path.Combine(Env.AppRootDir, @"..\external_tools\external_tools\image_tools\pdfcpu\pdfcpu.exe"),
            Path.Combine(Env.AppRootDir, @"..\external_tools\external_tools\image_tools\ImageMagick-portable-Q16-HDRI-x64\gswin64c.exe")
        ));

        public static readonly FfMpegUtil FfMpeg = new FfMpegUtil(new FfMpegUtilOptions(
            Path.Combine(Env.AppRootDir, @"_dummy.exe"),
            Path.Combine(Env.AppRootDir, @"_dummy.exe")));

        public static readonly PdfYomitokuLib YomiToku = new PdfYomitokuLib(Path.Combine(Env.AppRootDir, @"..\external_tools\external_tools\image_tools\yomitoku"));

        public static readonly AiUtilBasicSettings Settings = new AiUtilBasicSettings
        {
            AiTest_RealEsrgan_BaseDir = Path.Combine(Env.AppRootDir, @"..\external_tools\external_tools\image_tools\RealEsrgan\RealEsrgan_Repo"),
            AiTest_TesseractOCR_Data_Dir = Path.Combine(Env.AppRootDir, @"..\external_tools\external_tools\image_tools\TesseractOCR_Data"),
        };
        public static readonly AiTask Task = new AiTask(Settings, FfMpeg);

        public const string Post_OCR_Dir = "Post_OCR_Dir";
    }

    public static partial class Commands
    {
        [ConsoleCommand(
            "ConvertPdf command",
            "ConvertPdf [srcDir] [/dst:dstDir] [/ocr:yes|no] [/recompressOcrPdf:yes|no] [/downscaleOcrPdf:yes|no] [/ocrPdfTargetDpi:1-1200] [/ocrPdfGrayscale:yes|no] [/ocrPdfJpegQuality:0-100]",
            "OCR後Ghostscript: /recompressOcrPdf（正式）/downscaleOcrPdf（互換）。/ocrPdfTargetDpi /ocrPdfGrayscale /ocrPdfJpegQuality（0=既定、1-100=JPEG品質%%）は recompress 有効時のみ。再圧縮だけなら RecompressPdf。README の「PDF 再圧縮」参照。")]
        public static async Task<int> ConvertPdf(ConsoleService c, string cmdName, string str)
        {
            ConsoleParam[] args =
            {
                new ConsoleParam("[srcDir]", ConsoleService.Prompt, "Source directory path: ", ConsoleService.EvalNotEmpty, null),
                new ConsoleParam("dst", ConsoleService.Prompt, "Destination directory path: ", ConsoleService.EvalNotEmpty, null),
                new ConsoleParam("ocr", ConsoleService.Prompt, "Perform Japanese High-Quality OCR? (Y/N): ", null, null),
                new ConsoleParam("downscaleOcrPdf", null, null, null, null),
                new ConsoleParam("recompressOcrPdf", null, null, null, null),
                new ConsoleParam("ocrPdfTargetDpi", null, null, null, null),
                new ConsoleParam("ocrPdfGrayscale", null, null, null, null),
                new ConsoleParam("ocrPdfJpegQuality", null, null, null, null),
            };
            ConsoleParamValueList vl = c.ParseCommandList(cmdName, str, args);

            string srcDir = vl.DefaultParam.StrValue;
            string dstDir = vl["dst"].StrValue;

            srcDir = PP.RemoveLastSeparatorChar(await Lfs.NormalizePathAsync(srcDir, normalizeRelativePathIfSupported: true));
            dstDir = PP.RemoveLastSeparatorChar(await Lfs.NormalizePathAsync(dstDir, normalizeRelativePathIfSupported: true));

            $"- Source Dir: \"{srcDir}\""._Print();
            $"- Destination Dir: \"{dstDir}\""._Print();

            if (srcDir._IsSamei(dstDir))
            {
                throw new CoresException("srcDir must not be same to dstDir.");
            }

            await Lfs.CreateDirectoryAsync(dstDir);

            SuperPerformPdfOptions options = new SuperPerformPdfOptions {/* MaxPagesForDebug = 120, SaveDebugPng = true, SkipRealesrgan = true */ };

            bool performOcr = vl["ocr"].BoolValue;
            bool ghostscriptRecompressOcrPdf = vl["downscaleOcrPdf"].BoolValue || vl["recompressOcrPdf"].BoolValue;
            int ocrPdfTargetDpi = vl.GetInt("ocrPdfTargetDpi");
            if (ocrPdfTargetDpi < 1)
            {
                ocrPdfTargetDpi = 200;
            }
            if (ocrPdfTargetDpi > 1200)
            {
                throw new CoresException("ocrPdfTargetDpi must be between 1 and 1200.");
            }
            bool ocrPdfGrayscale = vl["ocrPdfGrayscale"].BoolValue;
            int ocrPdfJpegQuality = vl.GetInt("ocrPdfJpegQuality");
            if (ocrPdfJpegQuality < 0 || ocrPdfJpegQuality > 100)
            {
                throw new CoresException("ocrPdfJpegQuality must be 0 (Ghostscript default) or 1-100 (JPEG quality percent, higher = better quality / larger file).");
            }

            if (performOcr)
            {
                ""._Print();
                "***"._Print();
                $"The \"ocr\" option is enabled. This OCR feature uses \"YomiKaku\" AI engine published by kotaro.kinoshita-san. Plesae read the https://github.com/kotaro-kinoshita/yomitoku/blob/cba0a134e0d2ad3bfdce163231b3cb91de07928e/README.md license document."._Print();
                "***"._Print();
                ""._Print();
            }

            var srcFiles = (await Lfs.EnumDirectoryAsync(srcDir, true)).Where(x => x.IsFile && x.Name.StartsWith("_") == false && x.Name._IsExtensionMatch(".pdf")).OrderBy(x => x.FullPath, StrCmpi)._Shuffle().ToList();

            int numTotal = srcFiles.Count();
            int numOk = 0;
            int numError = 0;
            int numSkip = 0;

            $"Total {numTotal} Files"._Error();

            int currentNumber = 0;

            List<string> errorFilesList = new();

            foreach (var src in srcFiles)
            {
                currentNumber++;
                string relativePath = PP.GetRelativeFileName(src.FullPath, srcDir);
                string dstPath = PP.Combine(dstDir, relativePath);

                $"<< {currentNumber} / {numTotal} >> '{src.FullPath}' Start"._Error();

                try
                {
                    if (await SuperPdfUtil.PerformPdfAsync(src.FullPath, dstPath, options) == false)
                    {
                        numSkip++;
                        $"<< {currentNumber} / {numTotal} >> '{src.FullPath}' Skip"._Error();
                    }
                    else
                    {
                        numOk++;
                        $"<< {currentNumber} / {numTotal} >> '{src.FullPath}' OK"._Error();
                    }
                }
                catch (Exception ex)
                {
                    Con.WriteLine($"<< {currentNumber} / {numTotal} >> Error: {src.FullPath} -> {dstPath}");
                    ex._Error();
                    errorFilesList.Add(src.FullPath);
                    numError++;
                }
            }

            if (performOcr)
            {
                Con.WriteLine("Performing Japanese OCR started ...");
                if (ghostscriptRecompressOcrPdf)
                {
                    Con.WriteLine($"Ghostscript after OCR PDF: enabled. TargetDpi={ocrPdfTargetDpi}, Grayscale={ocrPdfGrayscale}, JpegQuality%={(ocrPdfJpegQuality == 0 ? "(default)" : ocrPdfJpegQuality.ToString())}.");
                    Con.WriteLine("  (/recompressOcrPdf:yes … 任意: /ocrPdfTargetDpi:N /ocrPdfGrayscale:yes /ocrPdfJpegQuality:0-100)");
                    Con.WriteLine("  注意: README の「PDF 再圧縮」または ConvertPdf 節を参照。再圧縮のみは RecompressPdf。");
                }

                await SuperBookExternalTools.YomiToku.PerformOcrDirAsync(dstDir, PP.Combine(dstDir, SuperBookExternalTools.Post_OCR_Dir), SuperBookExternalTools.Post_OCR_Dir, ghostscriptRecompressOcrPdf, ocrPdfTargetDpi, ocrPdfGrayscale, ocrPdfJpegQuality);

                Con.WriteLine("Performing Japanese OCR completed.");
            }

            if (errorFilesList.Count >= 1)
            {
                $"--- Error files ---"._Error();
                foreach (var errFile in errorFilesList)
                {
                    $"- {errFile}"._Error();
                }
            }

            $"\n\n<< ConvertPdf Result >>\nnumTotal = {numTotal}, numSkip = {numSkip}, numOk = {numOk}, numError = {numError}\n\n"._Error();

            return 0;
        }

        [ConsoleCommand(
            "RecompressPdf command",
            "RecompressPdf [srcDir] [/dst:dstDir] [/ocrPdfTargetDpi:1-1200] [/ocrPdfGrayscale:yes|no] [/ocrPdfJpegQuality:0-100]",
            "Ghostscript のみで PDF を再圧縮（Real-ESRGAN・版面処理・OCR は行わない）。既存 PDF のみ対象。詳細は README の「PDF 再圧縮（RecompressPdf）」。")]
        public static async Task<int> RecompressPdf(ConsoleService c, string cmdName, string str)
        {
            ConsoleParam[] args =
            {
                new ConsoleParam("[srcDir]", ConsoleService.Prompt, "Source directory path: ", ConsoleService.EvalNotEmpty, null),
                new ConsoleParam("dst", ConsoleService.Prompt, "Destination directory path: ", ConsoleService.EvalNotEmpty, null),
                new ConsoleParam("ocrPdfTargetDpi", null, null, null, null),
                new ConsoleParam("ocrPdfGrayscale", null, null, null, null),
                new ConsoleParam("ocrPdfJpegQuality", null, null, null, null),
            };
            ConsoleParamValueList vl = c.ParseCommandList(cmdName, str, args);

            string srcDir = vl.DefaultParam.StrValue;
            string dstDir = vl["dst"].StrValue;

            srcDir = PP.RemoveLastSeparatorChar(await Lfs.NormalizePathAsync(srcDir, normalizeRelativePathIfSupported: true));
            dstDir = PP.RemoveLastSeparatorChar(await Lfs.NormalizePathAsync(dstDir, normalizeRelativePathIfSupported: true));

            $"- Source Dir: \"{srcDir}\""._Print();
            $"- Destination Dir: \"{dstDir}\""._Print();

            if (srcDir._IsSamei(dstDir))
            {
                throw new CoresException("srcDir must not be same to dstDir.");
            }

            int targetDpi = vl.GetInt("ocrPdfTargetDpi");
            if (targetDpi < 1)
            {
                targetDpi = 200;
            }
            if (targetDpi > 1200)
            {
                throw new CoresException("ocrPdfTargetDpi must be between 1 and 1200.");
            }
            bool grayscale = vl["ocrPdfGrayscale"].BoolValue;
            int jpegQuality = vl.GetInt("ocrPdfJpegQuality");
            if (jpegQuality < 0 || jpegQuality > 100)
            {
                throw new CoresException("ocrPdfJpegQuality must be 0 (Ghostscript default) or 1-100 (JPEG quality percent, higher = better quality / larger file).");
            }

            Con.WriteLine($"Ghostscript recompress only: TargetDpi={targetDpi}, Grayscale={grayscale}, JpegQuality%={(jpegQuality == 0 ? "(default)" : jpegQuality.ToString())}.");

            await Lfs.CreateDirectoryAsync(dstDir);

            var srcFiles = (await Lfs.EnumDirectoryAsync(srcDir, true)).Where(x => x.IsFile && x.Name.StartsWith("_") == false && x.Name._IsExtensionMatch(".pdf")).OrderBy(x => x.FullPath, StrCmpi).ToList();

            int numTotal = srcFiles.Count;
            int numOk = 0;
            int numError = 0;
            List<string> errorFilesList = new();

            $"Total {numTotal} PDF files"._Error();

            int currentNumber = 0;
            foreach (var src in srcFiles)
            {
                currentNumber++;
                string relativePath = PP.GetRelativeFileName(src.FullPath, srcDir);
                string dstPath = PP.Combine(dstDir, relativePath);

                $"<< {currentNumber} / {numTotal} >> '{src.FullPath}'"._Error();

                try
                {
                    await Lfs.EnsureCreateDirectoryForFileAsync(dstPath);
                    string tmpOut = await Lfs.GenerateUniqueTempFilePathAsync("recompress_pdf", ".pdf");
                    try
                    {
                        await SuperBookExternalTools.ImageMagick.CompressPdfWithGhostscriptAsync(
                            src.FullPath, tmpOut, targetDpi, grayscale, jpegQuality);
                        await Lfs.CopyFileAsync(tmpOut, dstPath);
                    }
                    finally
                    {
                        await Lfs.DeleteFileIfExistsAsync(tmpOut);
                    }
                    numOk++;
                    $"<< {currentNumber} / {numTotal} >> OK"._Error();
                }
                catch (Exception ex)
                {
                    Con.WriteLine($"<< {currentNumber} / {numTotal} >> Error: {src.FullPath} -> {dstPath}");
                    ex._Error();
                    errorFilesList.Add(src.FullPath);
                    numError++;
                }
            }

            if (errorFilesList.Count >= 1)
            {
                $"--- Error files ---"._Error();
                foreach (var errFile in errorFilesList)
                {
                    $"- {errFile}"._Error();
                }
            }

            $"\n\n<< RecompressPdf Result >>\nnumTotal = {numTotal}, numOk = {numOk}, numError = {numError}\n\n"._Error();

            return 0;
        }
    }
}
