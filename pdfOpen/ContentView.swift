//
//  ContentView.swift
//  pdfOpen
//
//  Created by Shubhrat Agrawal on 16/06/21.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ContentView: View {

  @State var showDocPicker = false
  var body: some View {
    Button("Show document picker") {
      self.showDocPicker.toggle()
    }
    .documentPicker(
      isPresented: $showDocPicker,
      documentTypes: ["public.folder"]
        , onDocumentsPicked:  { urls in
              print("Selected folder: \(urls.first!)")
            
            })
    guard let doc = PDFDocument(url: URL(fileURLWithPath: "/tmp/spec.pdf")) else {
        fatalError("Cannot open file spec.pdf")
    }

    try extractImages(from: doc) { image, page, name in
        do {
            switch image {
            case .jpg(let data):
                try data.write(to: URL(fileURLWithPath: "/tmp/images/Page \(page) \(name).jpg"))
            case .raw(let cgImage):
                let data = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)).tiffRepresentation!
                try data.write(to: URL(fileURLWithPath: "/tmp/images/Page \(page) \(name).tiff"))
            }
        } catch {
            print("☢️ cannot write image of page", page)
        }
    }
  }
    
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
