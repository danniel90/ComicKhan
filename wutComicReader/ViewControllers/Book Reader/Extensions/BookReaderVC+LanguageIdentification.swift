//
//  BookReaderVC+LanguageIdentification.swift
//  wutComicReader
//
//  Created by Daniel on 9/6/22.
//

import UIKit
import MLKit
import Vision

extension BookReaderVC {
    func recognizeTextHandler(request: VNRequest, error: Error?) {
        DispatchQueue.main.async { [unowned self] in
               if let results = request.results, !results.isEmpty {
                   if let requestResults = request.results as? [VNRecognizedTextObservation] {
                       var recognizedTextString = ""
                       for observation in requestResults {
                           let recognizedText = observation.topCandidates(1)[0].string
                           recognizedTextString += "\(recognizedText.replacingOccurrences(of: "\r\n|\n|\r|\n", with: " ")) "
                           if recognizedText.count > 200 {
                               continue
                           }
                       }

                       print("Recoginized Text String: \(recognizedTextString)")
                       self.identifyLanguage(recognizedTextString)
                   }
               } else {
   //                self.showAlert(with: "Oh!", description: "Could not recognize text in comic page.")
                   print("Could not recognize text in comic page.")
               }
        }
    }
    
    func identifyLanguage(_ text: String) {
        self.languageId.identifyLanguage(for: text) { (languageTag, error) in
            if let error = error {
            print("Failed with error: \(error)")
            return
            }

            print("Identified Language: \(languageTag!)")
            if let languageCode = languageTag, languageCode != "und" {
                try? self.dataService.saveInputLanguageOf(comic: self.comic!, inputLanguage: languageCode)

                let language = Locale.current.localizedString(forLanguageCode: languageCode)!
                self.showAlert(with: "Identified \(language) Language", description: "Identified \(language) (\(languageCode)) language in first sentences of comic page.")
                
                let bookPage = self.bookPageViewController.viewControllers?.first as! BookPage
                bookPage.startImageProcessing()
            } else {
                self.showAlert(with: "Language Not Identified in first attempt, will retry", description: "Could not identify the language in first senteces of comic page. Will retry the language identification")
                
                self.identifyPossibleLanguages(text)
            }
        }
    }
    
    func identifyPossibleLanguages(_ text: String)  {
        self.languageId.identifyPossibleLanguages(for: text) { (identifiedLanguages, error) in
            if let error = error {
                print("Failed with error: \(error)")
                return
            }

            let text = "Identified Languages:\n"
                + identifiedLanguages!.map {
                      String(format: "(%@, %.2f)", $0.languageTag, $0.confidence)
                }.joined(separator: "\n")
            print(text)
            
            let identifiedLanguages = identifiedLanguages!
                .map{
                    ($0.languageTag, $0.confidence)
                }
                .sorted{
                    $0.1 > $1.1
                }
            let languageCode = identifiedLanguages.first?.0
            let confidence = identifiedLanguages.first?.1
            
            if let languageCode = languageCode, languageCode != "und", let confidence = confidence {
                try? self.dataService.saveInputLanguageOf(comic: self.comic!, inputLanguage: languageCode)

                let language = Locale.current.localizedString(forLanguageCode: languageCode)!
                self.showAlert(with: "Identified \(language) Language", description: "Identified \(language) (\(languageCode)) language in first sentences of comic page with a \(confidence*100) confidence.")
                
                let bookPage = self.bookPageViewController.viewControllers?.first as! BookPage
                bookPage.startImageProcessing()
            } else {
                self.showAlert(with: "Language Not Identified", description: "Could not identify the language in first senteces of comic page.")
            }
        }
    }
    
    func updateLanguageDetectRequestParameters() {
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesCPUOnly = false
        textRecognitionRequest.preferBackgroundProcessing = false
        
        do {
        // Set the primary language.
        if #available(iOS 15.0, *) {
            textRecognitionRequest.recognitionLanguages = try textRecognitionRequest.supportedRecognitionLanguages()
            textRecognitionRequest.recognitionLanguages.insert(contentsOf: ["zh-Hans", "zh-Hant"], at: 0)
        } else {
            // Fallback on earlier versions
            // .accurate
            //https://stackoverflow.com/a/60654614
            textRecognitionRequest.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "fr-FR", "it-IT", "de-DE", "es-ES", "pt-BR"]
        }
        } catch {
            showAlert(with: "Oh!", description: "There is a problem with loading Apple's recognitionLanguages for language detection.")
            return
        }
    }
    
    func performOCRLanguageDetectRequest() {
        textRecognitionRequest.cancel()
        
        updateLanguageDetectRequestParameters()
        DispatchQueue.global(qos: .userInteractive).async { [unowned self] in
            do {
                try self.requestHandler?.perform([self.textRecognitionRequest])
            } catch _ {}
        }
    }
}
