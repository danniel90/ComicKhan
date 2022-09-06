//
//  BookReaderVC+BookPageDelegate.swift
//  wutComicReader
//
//  Created by Daniel on 9/3/22.
//

import MLKit
import Vision

extension BookReaderVC: BookPageDelegate {
    func saveTranslationsToCoreData(at pageViewIndex: Int, on page: Int, translationsResult: [(CGRect, String)]) {
        if translationsResult.count > 0 {
            guard let language = comic?.lastOutputLanguage else {
                return
            }

            try? dataService.saveTranslationsToCoreData(comic: comic, translationsResult: translationsResult, with: language, on: Int16(page))
        }
    }
    
    func imageDidChange(at pageViewIndex: Int, on pageNumber: Int?) {
        removeDetectionAnnotations(at: pageViewIndex)
        
        let pageView = self.getPageView(at: pageViewIndex)
        guard let image = pageView.image else { return }
        guard comic?.inputLanguage != nil && comic?.inputLanguage != "none" else { return }
        guard pageNumber != nil else { return }
        
        //try fetch from store
        let translationsFromCoreData = fetchTranslationsFromCoreData(on: pageNumber!)
        if translationsFromCoreData.count > 0 {
            DispatchQueue.main.async {
                let pageView = self.getPageView(at: pageViewIndex)

                for (transformedRect, translatedText) in translationsFromCoreData {
                    let displayResult = self.getTextView(transformedRect, translatedText)
                    let label = displayResult.1
                    label.backgroundColor = .black
                    pageView.addSubview(label)
                }
            }
            return
        }
        //if fetch empty
        //TODO: detect
        var textRecognizer: TextRecognizer
        var languageOptions: CommonTextRecognizerOptions

        let language = comic?.inputLanguage
        
        if language == "detect" {
            print("detect input language selected for translate")

            if let cgImage = image.cgImage {
                // Create the request handler.
                requestHandler = VNImageRequestHandler(cgImage: cgImage)
                
                // Perform the request.
                performOCRLanguageDetectRequest()
            } else {
                // Clean up the Vision objects.
                textRecognitionRequest.cancel()
                requestHandler = nil
            }
            //temp
            return
        }
        
        switch language {
        case "zh":
            languageOptions = ChineseTextRecognizerOptions()
        case "ja":
            languageOptions = JapaneseTextRecognizerOptions()
        case "ko":
            languageOptions = JapaneseTextRecognizerOptions()
        case "none":
            print("none input language selected for translate")
            return
        //TODO: DETECT LANGUAGE
        case "":
            print("no input language selected for translate")
            return
        case nil:
            return
        default:
            languageOptions = TextRecognizerOptions()

        }
        textRecognizer = TextRecognizer.textRecognizer(options: languageOptions)

        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation
        DispatchQueue.global(qos: .userInitiated).async {
            self.process(visionImage, with: textRecognizer, at: pageViewIndex, on: pageNumber!)
        }
    }
}
