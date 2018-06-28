//
//  ViewController.swift
//  HPIViewer
//
//  Created by Friedrich HAEUPL on 11.04.17.
//  Copyright © 2017 Friedrich HAEUPL. All rights reserved.
//

import Cocoa

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
        return runModal() == NSFileHandlingPanelOKButton ? urls.first : nil
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
                
                // subdata
                // let hpi_header = Data(data.subdata(in: header_range))
                // print("hpi_header     = \(hpi_header)")

                /*
                    For NSData:
                        var values = [UInt8](repeating:0, count:data!.length)
                        data.getBytes(&values, length: data!.length)
                    For Data:
                        var values = [UInt8](repeating:0, count:data!.count)
                        data.copyBytes(to: &values, count: data!.count)
                 */
                // create array of appropriate length:
                var hpi_header = [UInt8](repeating: 0, count: 32)
                // copy bytes into array
                data.copyBytes(to: &hpi_header, count: 32)
                print("bytes           = \(hpi_header)")

                
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
                print("signature       = \(signature)")
                
                let version_int:Int = Int(hpi_header[8]) + Int(hpi_header[9])<<8 + Int(hpi_header[10])<<16 + Int(hpi_header[11])<<24
                
                let jpeg_start_int:Int	=
                    Int(hpi_header[12]) + Int(hpi_header[13])<<8 + Int(hpi_header[14])<<16 + Int(hpi_header[15])<<24
                
                let jpeg_length_int:Int	=
                    Int(hpi_header[16]) + Int(hpi_header[17])<<8 + Int(hpi_header[18])<<16 + Int(hpi_header[19])<<24
                
                let mask_start_int:Int	=
                    Int(hpi_header[20]) + Int(hpi_header[21])<<8 + Int(hpi_header[22])<<16 + Int(hpi_header[23])<<24
                
                let mask_length_int:Int	=
                    Int(hpi_header[24]) + Int(hpi_header[25])<<8 + Int(hpi_header[26])<<16 + Int(hpi_header[27])<<24
 
                print("version          = \(version_int)")
                print("jpeg_start_int   = \(jpeg_start_int)")
                print("jpeg_length_int  = \(jpeg_length_int)")
                print("mask_start_int   = \(mask_start_int)")
                print("mask_length_int  = \(mask_length_int)")
                
                // extract the jpg ----------------------------------------------
                
                // let jpg_range:NSRange = NSMakeRange(jpeg_start_int, jpeg_length_int)
                // let jpg_data = Data(data.subdata(in: jpg_range))
                // var jpg_data: Data = Data(data.subdata(in: NSRange(location: jpeg_start_int, length: jpeg_length_int)))
                
                // http://stackoverflow.com/questions/29262624/nsimage-to-nsdata-as-png-swift
                
                // let jpg_data:Data = data.subdata(in: jpeg_start_int..<jpeg_start_int+jpeg_length_int)
                // print("jpg_data       = \(jpg_data)")
                // let image:NSImage = NSImage(data: jpg_data)!
                // let jpg_bits:NSBitmapImageRep = NSBitmapImageRep(data:  jpg_data)!
                
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

            }
            

        } else {
            print("file selection was canceled")
        }
    }


}

