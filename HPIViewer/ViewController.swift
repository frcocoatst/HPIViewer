//
//  ViewController.swift
//  HPIViewer
//
//  Created by Friedrich HAEUPL on 11.04.17.
//  Copyright © 2017 Friedrich HAEUPL. All rights reserved.
//

import Cocoa
import CoreImage

// MARK: - HPI Header (modern)
private struct HPIHeader {
    let version: UInt32
    let jpegStart: UInt32
    let jpegLength: UInt32
    let maskStart: UInt32
    let maskLength: UInt32

    init(bytes: [UInt8]) {
        func u32LE(_ o: Int) -> UInt32 {
            return UInt32(bytes[o])
                | (UInt32(bytes[o+1]) << 8)
                | (UInt32(bytes[o+2]) << 16)
                | (UInt32(bytes[o+3]) << 24)
        }
        self.version    = u32LE(8)
        self.jpegStart  = u32LE(12)
        self.jpegLength = u32LE(16)
        self.maskStart  = u32LE(20)
        self.maskLength = u32LE(24)
    }
}


// there are already connections setup in IB for openDocument/saveDocument/newDocumnet
// http://stackoverflow.com/questions/28008262/detailed-instruction-on-use-of-nsopenpanel

extension NSOpenPanel {
    var selectUrl: URL? {
        title = "Select File"
        allowsMultipleSelection = false
        canChooseDirectories = false
        canChooseFiles = true
        canCreateDirectories = false
        //allowedFileTypes = ["jpg","png","pdf","pct", "bmp", "tiff"]
        // to allow only images, just comment out this line to allow any file type to be selected
        // allow only *.hpi Files
        allowedFileTypes = ["hpi","HPI"]
        return runModal() == .OK ? urls.first : nil
    }
}


class ViewController: NSViewController {

    @IBOutlet weak var maskView: NSImageView!
    @IBOutlet weak var imageView: NSImageView!
    //
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func saveDocument(_ sender: NSMenuItem) {
        print("SAVE")
    }
    @IBAction func newDocument(_ sender: NSMenuItem) {
        print("NEW")
    }
    // connect your view controller to the first responder window adding the openDocument method
    @IBAction func openDocument(_ sender: NSMenuItem) {
        print("openDocument ViewController")
        
        // http://stackoverflow.com/questions/30093688/how-to-create-range-in-swift
        // http://stackoverflow.com/questions/39655472/nsdata-to-data-swift-3
        
        // let header_range: Range = 0..<32

        if let url = NSOpenPanel().selectUrl {
            
            print("file selected  = \(url.path)")
            print("filename       = \(url.lastPathComponent)")
            print("pathExtension  = \(url.pathExtension)")
            
            let data = NSData(contentsOf: url as URL) as Data?  // <==== Added 'as Data?'
            if let data = data {                                // <==== Added 'if let'
                print("data           = \(data)")
                
                // create array of appropriate length:
                var hpi_header = [UInt8](repeating: 0, count: 32)
                // copy bytes into array
                data.copyBytes(to: &hpi_header, count: 32)
                print("hpi_header       = \(hpi_header)")

                
                // change this to STRING ???
                var signature = [UInt8](repeating: 0, count: 9)
                
                // for (i=0; i<8; i++)
                for i in 0..<8 {
                    if ((hpi_header[i] >= 0x20) && (hpi_header[i] < 0x80))
                    {
                        signature[i] = hpi_header[i]
                    }
                    else
                    {
                        signature[i] = 0x32
                    }
                }
                print("signature        = \(signature)")

                // Parse HPI header once (little endian 32-bit fields)
                let header = HPIHeader(bytes: hpi_header)

                // Backward-compatible aliases (Int for legacy usage)
                let version_int: Int      = Int(header.version)
                let jpeg_start_int: Int   = Int(header.jpegStart)
                let jpeg_length_int: Int  = Int(header.jpegLength)
                let mask_start_int: Int   = Int(header.maskStart)
                let mask_length_int: Int  = Int(header.maskLength)

                // Int(hpi_header[12]) + Int(hpi_header[13])<<8 + Int(hpi_header[14])<<16 + Int(hpi_header[15])<<24
 
                print("version          = \(version_int)")
                print("jpeg_start_int   = \(jpeg_start_int)")
                print("jpeg_length_int  = \(jpeg_length_int)")
                print("mask_start_int   = \(mask_start_int)")
                print("mask_length_int  = \(mask_length_int)")
                
                // extract the jpg ----------------------------------------------
                // http://stackoverflow.com/questions/29262624/nsimage-to-nsdata-as-png-swift

                
                let jpg_data:Data = data.subdata(in: jpeg_start_int ..< jpeg_start_int+jpeg_length_int)
                let image:NSImage = NSImage(data: jpg_data)!
                
                // Display the image in an imageview
                // imageView.image = NSImage(contentsOf: url)
                imageView.image = image

                let mask_data:Data = data.subdata(in: mask_start_int ..< mask_start_int+mask_length_int)
                let mask:NSImage = NSImage(data: mask_data)!
                
                // Display the image in an imageview
                // imageView.image = NSImage(contentsOf: url)
                maskView.image = mask
                
                // we have image and mask
                
                //let image = NSImage(contentsOfFile: "/path/to/image.png")!
                //let mask = NSImage(contentsOfFile: "/path/to/mask.png")!

                /*
                let outputURL = FileManager.default
                    .urls(for: .desktopDirectory, in: .userDomainMask)
                    .first!
                    .appendingPathComponent("output.png")

                do {
                    try combineImageWithMask(image: image, mask: mask, saveTo: outputURL)
                    print("Image saved to \(outputURL.path)")
                } catch {
                    print("Error: \(error)")
                }
                */
                // ---
                
                do {
                    try exportMaskedPNGToDesktop(baseImage: image, maskImage: mask, invertMask: false, fileName: "output.png")
                 } catch {
                    NSLog("Export-Fehler: \(error.localizedDescription)")
                 }
                
                // ---

            }
            

        } else {
            print("file selection was canceled")
        }
    }
    
    // ---
    
    /// Exports a masked PNG to the user's Desktop.
    /// - Parameters:
    ///   - baseImage: The base/content image.
    ///   - maskImage: The mask image (white = visible, black = transparent). RGB or grayscale are fine.
    ///   - invertMask: Set to `true` if your mask is inverted (white=transparent, black=opaque).
    ///   - fileName: File name for the PNG on the Desktop (e.g. "output.png").
    func exportMaskedPNGToDesktop(baseImage: NSImage,
                                  maskImage: NSImage,
                                  invertMask: Bool = false,
                                  fileName: String = "output.png") throws {
        let outURL = Self.desktopURL(appending: fileName)
        try Self.combineWithMask_CI(base: baseImage, mask: maskImage, invertMask: invertMask, outURL: outURL)
        print("✅ PNG gespeichert: \(outURL.path)");
    }
    
    /// Combine base + mask using Core Image and write PNG with alpha.
    static func combineWithMask_CI(base: NSImage, mask: NSImage, invertMask: Bool, outURL: URL) throws {
        // Convert NSImage -> CIImage safely
        func ciImage(_ ns: NSImage) throws -> CIImage {
            var rect = CGRect(origin: .zero, size: ns.size)
            guard let cg = ns.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
                throw NSError(domain: "ImageError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "NSImage konnte nicht in CGImage konvertiert werden."])
            }
            return CIImage(cgImage: cg)
        }

        let baseCI = try ciImage(base)
        var maskCI = try ciImage(mask)

        // Ensure mask has same extent as base (scale if needed)
        let targetSize = baseCI.extent.size
        if maskCI.extent.size != targetSize {
            let scaleX = targetSize.width  / maskCI.extent.width
            let scaleY = targetSize.height / maskCI.extent.height
            maskCI = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                .cropped(to: CGRect(origin: .zero, size: targetSize))
        }

        // Invert mask if needed (white <-> black)
        if invertMask {
            guard let invert = CIFilter(name: "CIColorInvert") else {
                throw NSError(domain: "ImageError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "CIColorInvert Filter nicht verfügbar."])
            }
            invert.setValue(maskCI, forKey: kCIInputImageKey)
            guard let invOut = invert.outputImage else {
                throw NSError(domain: "ImageError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Maske konnte nicht invertiert werden."])
            }
            maskCI = invOut
        }

        // Transparent background (what becomes 'outside' of the mask)
        let transparentBG = CIImage(color: .clear).cropped(to: baseCI.extent)

        // Blend with mask: white = show input image, black = show background (transparent)
        guard let blend = CIFilter(name: "CIBlendWithMask") else {
            throw NSError(domain: "ImageError", code: 1004, userInfo: [NSLocalizedDescriptionKey: "CIBlendWithMask Filter nicht verfügbar."])
        }
        blend.setValue(baseCI,        forKey: kCIInputImageKey)
        blend.setValue(transparentBG, forKey: kCIInputBackgroundImageKey)
        blend.setValue(maskCI,        forKey: kCIInputMaskImageKey)

        guard let output = blend.outputImage else {
            throw NSError(domain: "ImageError", code: 1005, userInfo: [NSLocalizedDescriptionKey: "CIBlendWithMask lieferte kein Bild."])
        }

        // Render to CGImage with alpha and write PNG
        let ciContext = CIContext(options: nil)
        guard let cgOut = ciContext.createCGImage(output, from: output.extent) else {
            throw NSError(domain: "ImageError", code: 1006, userInfo: [NSLocalizedDescriptionKey: "CGImage aus CIImage konnte nicht erstellt werden."])
        }

        let rep = NSBitmapImageRep(cgImage: cgOut)
        rep.size = NSSize(width: targetSize.width, height: targetSize.height)

        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ImageError", code: 1007, userInfo: [NSLocalizedDescriptionKey: "PNG-Encoding fehlgeschlagen."])
        }
        try png.write(to: outURL)
    }

    // MARK: - Helpers

    /// Desktop URL helper
    static func desktopURL(appending fileName: String) -> URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            .appendingPathComponent(fileName)
    }
    
    
    // ---
    /*
    func invertedCGImage(from image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let bitsPerComponent = image.bitsPerComponent
        let bytesPerRow = image.bytesPerRow
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        // Draw the original mask
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Get the pixel buffer and invert values
        if let buffer = context.data {
            let ptr = buffer.bindMemory(to: UInt8.self, capacity: height * bytesPerRow)
            for i in 0 ..< (height * bytesPerRow) {
                ptr[i] = 255 - ptr[i] // Invert grayscale
            }
        }
        
        return context.makeImage()
    }

    
    func combineImageWithMask(image: NSImage, mask: NSImage, saveTo url: URL) throws {
        // Helper: convert NSImage → CGImage
        func cgImage(from nsImage: NSImage) -> CGImage? {
            var rect = CGRect(origin: .zero, size: nsImage.size)
            return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        
        guard let baseCG = cgImage(from: image),
              let maskCG = cgImage(from: mask) else {
            throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert NSImage to CGImage"])
        }
        
        /* Create a CGImageMask from the mask image
        guard let cgMask = CGImage(
            maskWidth: maskCG.width,
            height: maskCG.height,
            bitsPerComponent: maskCG.bitsPerComponent,
            bitsPerPixel: maskCG.bitsPerPixel,
            bytesPerRow: maskCG.bytesPerRow,
            provider: maskCG.dataProvider!,
            decode: nil,
            shouldInterpolate: false
        ) else {
            throw NSError(domain: "ImageError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create mask"])
        }
         */
        
        guard let invertedMask = invertedCGImage(from: maskCG),
              let cgMask = CGImage(
                maskWidth: invertedMask.width,
                height: invertedMask.height,
                bitsPerComponent: invertedMask.bitsPerComponent,
                bitsPerPixel: invertedMask.bitsPerPixel,
                bytesPerRow: invertedMask.bytesPerRow,
                provider: invertedMask.dataProvider!,
                decode: nil,
                shouldInterpolate: false
              ) else {
            throw NSError(domain: "ImageError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create inverted mask"])
        }
        
        // Apply mask
        guard let maskedImage = baseCG.masking(cgMask) else {
            throw NSError(domain: "ImageError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to mask image"])
        }
        
        // Save as PNG
        let bitmapRep = NSBitmapImageRep(cgImage: maskedImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ImageError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
        }
        
        try pngData.write(to: url)
    }
*/


}

