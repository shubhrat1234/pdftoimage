//
//  pdf.swift
//  pdftoimage
//
//  Created by Shubhrat Agrawal on 31/05/21.
//

import Foundation
import PDFKit

func extractImages(from pdf: PDFDocument, extractor: @escaping (ImageInfo)->Void) throws {
    for pageNumber in 0..<pdf.pageCount {
        guard let page = pdf.page(at: pageNumber) else {
            throw PDFReadError.couldNotOpenPageNumber(pageNumber)
        }
        try extractImages(from: page, extractor: extractor)
    }
}

func extractImages(from page: PDFPage, extractor: @escaping (ImageInfo)->Void) throws {
    let pageNumber = page.label ?? "unknown page"
    guard let page = page.pageRef else {
        throw PDFReadError.couldNotOpenPage(pageNumber)
    }

    guard let dictionary = page.dictionary else {
        throw PDFReadError.couldNotOpenDictionaryOfPage(pageNumber)
    }

    guard let resources = dictionary[CGPDFDictionaryGetDictionary, "Resources"] else {
        throw PDFReadError.couldNotReadResources(pageNumber)
    }

    if let xObject = resources[CGPDFDictionaryGetDictionary, "XObject"] {
        print("reading resources of page", pageNumber)

        func extractImage(key: UnsafePointer<Int8>, object: CGPDFObjectRef, info: UnsafeMutableRawPointer?) -> Bool {
            guard let stream: CGPDFStreamRef = object[CGPDFObjectGetValue, .stream] else { return true }
            guard let dictionary = CGPDFStreamGetDictionary(stream) else {return true}

            guard dictionary.getName("Subtype", CGPDFDictionaryGetName) == "Image" else {return true}

            let colorSpaces = dictionary.getNameArray(for: "ColorSpace") ?? []
            let filter = dictionary.getNameArray(for: "Filter") ?? []

            var format = CGPDFDataFormat.raw
            guard let data = CGPDFStreamCopyData(stream, &format) as Data? else { return false }

            extractor(
              ImageInfo(
                name: String(cString: key),
                colorSpaces: colorSpaces,
                filter: filter,
                format: format,
                data: data
              )
            )

            return true
        }

        CGPDFDictionaryApplyBlock(xObject, extractImage, nil)
    }
}

struct ImageInfo: CustomDebugStringConvertible {
    let name: String
    let colorSpaces: [String]
    let filter: [String]
    let format: CGPDFDataFormat
    let data: Data

    var debugDescription: String {
        """
          Image "\(name)"
           - color spaces: \(colorSpaces)
           - format: \(format == .JPEG2000 ? "JPEG2000" : format == .jpegEncoded ? "jpeg" : "raw")
           - filters: \(filter)
           - size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .binary))
        """
    }
}

extension CGPDFObjectRef {
    func getName<K>(_ key: K, _ getter: (OpaquePointer, K, UnsafeMutablePointer<UnsafePointer<Int8>?>)->Bool) -> String? {
        guard let pointer = self[getter, key] else { return nil }
        return String(cString: pointer)
    }

    func getName<K>(_ key: K, _ getter: (OpaquePointer, K, UnsafeMutableRawPointer?)->Bool) -> String? {
        guard let pointer: UnsafePointer<UInt8> = self[getter, key] else { return nil }
        return String(cString: pointer)
    }

    subscript<R, K>(_ getter: (OpaquePointer, K, UnsafeMutablePointer<R?>)->Bool, _ key: K) -> R? {
        var result: R!
        guard getter(self, key, &result) else { return nil }
        return result
    }

    subscript<R, K>(_ getter: (OpaquePointer, K, UnsafeMutableRawPointer?)->Bool, _ key: K) -> R? {
        var result: R!
        guard getter(self, key, &result) else { return nil }
        return result
    }

    func getNameArray(for key: String) -> [String]? {
        var object: CGPDFObjectRef!
        guard CGPDFDictionaryGetObject(self, key, &object) else { return nil }

        if let name = object.getName(.name, CGPDFObjectGetValue) {
            return [name]
        } else {
            guard let array: CGPDFArrayRef = object[CGPDFObjectGetValue, .array] else {return nil}
            var names = [String]()
            for index in 0..<CGPDFArrayGetCount(array) {
                guard let name = array.getName(index, CGPDFArrayGetName) else { continue }
                names.append(name)
            }
            return names
        }
    }
}

enum PDFReadError: Error {
    case couldNotOpenPageNumber(Int)
    case couldNotOpenPage(String)
    case couldNotOpenDictionaryOfPage(String)
    case couldNotReadResources(String)
    case cannotReadXObjectStream(xObject: String, page: String)
}
