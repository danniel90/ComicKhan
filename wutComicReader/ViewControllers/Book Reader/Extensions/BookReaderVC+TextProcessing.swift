//
//  BookReaderVC+TextProcessing.swift
//  wutComicReader
//
//  Created by Daniel on 9/3/22.
//

import UIKit
import MLKit
import Vision

extension BookReaderVC {
    // MARK: - Private
    func updateTranslatorOptions() {
        let inputLanguage = comic?.inputLanguage ?? "en"
        let outputLanguage = comic?.lastOutputLanguage ?? "es"
        
        let options = TranslatorOptions(sourceLanguage: TranslateLanguage(rawValue: inputLanguage), targetLanguage: TranslateLanguage(rawValue: outputLanguage))
        translator = Translator.translator(options: options)
    }
    
    func fetchTranslationsFromCoreData(on page: Int) -> [(CGRect, String)] {
        var translationsResult: [(CGRect, String)] = []
        guard comic?.lastOutputLanguage != nil else {
            return translationsResult
        }
        let translationsCoreData = try? dataService.fetchPageTranslationsOf(comic: comic!, on: Int16(page))
        
        
        for translation in translationsCoreData! as [PageTranslation] {
            let transformedRect = CGRect(x: CGFloat(translation.frameX), y: CGFloat(translation.frameY), width: CGFloat(translation.frameWidth), height: CGFloat(translation.frameHeight))
            let translatedText = translation.text!
            translationsResult.append((transformedRect, translatedText))
        }
        return translationsResult
    }
    
    func getPageView(at pageViewIndex: Int) -> UIImageView {
        let bookPage = self.bookPageViewController.viewControllers?.first as! BookPage
        var pageView: UIImageView
        
        if (pageViewIndex == 1) {
            pageView = bookPage.pageImageView1
        } else {
            pageView = bookPage.pageImageView2
        }
        return pageView
    }
    
    func removeDetectionAnnotations(at pageViewIndex: Int) {
        let pageView = self.getPageView(at: pageViewIndex)
        
        for annotationView in pageView.subviews {
            annotationView.removeFromSuperview()
        }
    }

    func transformMatrix(_ pageView: UIImageView) -> CGAffineTransform {
        guard let image = pageView.image else { return CGAffineTransform() }
        let imageViewWidth = pageView.frame.size.width
        let imageViewHeight = pageView.frame.size.height
        let imageWidth = image.size.width
        let imageHeight = image.size.height

        let imageViewAspectRatio = imageViewWidth / imageViewHeight
        let imageAspectRatio = imageWidth / imageHeight
        let scale =
        (imageViewAspectRatio > imageAspectRatio)
        ? imageViewHeight / imageHeight : imageViewWidth / imageWidth

        // Image view's `contentMode` is `scaleAspectFit`, which scales the image to fit the size of the
        // image view by maintaining the aspect ratio. Multiple by `scale` to get image's original size.
        let scaledImageWidth = imageWidth * scale
        let scaledImageHeight = imageHeight * scale
        let xValue = (imageViewWidth - scaledImageWidth) / CGFloat(2.0)
        let yValue = (imageViewHeight - scaledImageHeight) / CGFloat(2.0)

        var transform = CGAffineTransform.identity.translatedBy(x: xValue, y: yValue)
        transform = transform.scaledBy(x: scale, y: scale)
        return transform
    }
    
    func process(_ visionImage: VisionImage, with textRecognizer: TextRecognizer?, at pageViewIndex: Int, on pageNumber: Int) {
        weak var weakSelf = self
        textRecognizer?.process(visionImage) { [self] text, error in
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            guard error == nil, let text = text else {
                print(error?.localizedDescription ?? "")
                return
            }

            let pageView = self.getPageView(at: pageViewIndex)
            var displayResults: [(CGRect, UITextView, String)] = []
            // Blocks.
            for block in text.blocks {
                let transformedRect = block.frame.applying(strongSelf.transformMatrix(pageView))
                let displayResult = strongSelf.getTextView(transformedRect, block.text)
                pageView.addSubview(displayResult.1)
                displayResults.append(displayResult)
            }
            
            guard strongSelf.comic?.lastTranslateMode != 0 else {
                return
            }
            let translateMode = TranslateMode(rawValue: Int(comic!.lastTranslateMode))
            switch translateMode
            {
            case .onDevice:
                strongSelf.translateOnDevice(displayResults, at: pageViewIndex, on: pageNumber)
            case .online:
                strongSelf.translateOnline(displayResults, at: pageViewIndex, on: pageNumber)
            default:
                print(" MODE PENDING")
                return
            }
        }
    }
    
    func getTextView(_ transformedRect: CGRect, _ text: String) -> (CGRect, UITextView, String) {
        let label = UITextView(frame: transformedRect)
        label.text = text
        label.font = .systemFont(ofSize: 200)
        label.isUserInteractionEnabled = true
        label.isScrollEnabled = true
        label.scrollRangeToVisible(NSRange(location: 0,length: 0))
        label.setContentOffset(CGPoint(x: 0,y: 0), animated: false)
        self.updateTextFont(label)
        return (transformedRect, label, text)
    }
    
    //https://stackoverflow.com/a/27115350
    func updateTextFont(_ textView: UITextView) {
        if (textView.text.isEmpty || textView.bounds.size.equalTo(CGSize.zero)) {
            return;
        }

        let textViewSize = textView.frame.size;
        let fixedWidth = textViewSize.width;
        let expectSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat(MAXFLOAT)));

        var expectFont = textView.font;
        if (expectSize.height > textViewSize.height) {
            while (textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat(MAXFLOAT))).height > textViewSize.height && textView.font!.pointSize > 6.0) {
                expectFont = textView.font!.withSize(textView.font!.pointSize - 1)
                textView.font = expectFont
            }
        }
        else {
            while (textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat(MAXFLOAT))).height < textViewSize.height) {
                expectFont = textView.font;
                textView.font = textView.font!.withSize(textView.font!.pointSize + 1)
            }
            textView.font = expectFont;
        }
    }
    
    private func translateOnDevice(_ displayResults: [(CGRect, UITextView, String)], at pageViewIndex: Int, on pageNumber: Int) {
        let inputLanguage = comic?.inputLanguage ?? "none"
        let outputLanguage = comic?.lastOutputLanguage ?? "none"
        guard inputLanguage != "none" && outputLanguage != "none" else {
            print("will not translate when inputLanguage:\(inputLanguage) & outputLanguage:\(outputLanguage)")
            return
        }
        updateTranslatorOptions()
        
        weak var weakSelf = self
        let translatorForDownloading = self.translator!
        
        DispatchQueue.global(qos: .userInteractive).async {
            translatorForDownloading.downloadModelIfNeeded { error in
                guard error == nil else {
                  print("Failed to ensure model downloaded with error \(error!)")
                  return
                }
                
                var translateResults:[(CGRect, String)] = displayResults.map { ($0.0, $0.2) }

                for (index,(transformedRect, label, textString)) in displayResults.enumerated() {
                    if translatorForDownloading == self.translator {
                        let sourceText = textString
                        translatorForDownloading.translate(sourceText) { result, error in
                            guard error == nil else {
                                print("Failed with error \(error!)")
                                return
                            }
                            guard let strongSelf = weakSelf else {
                                print("Self is nil!")
                                return
                            }
                            if translatorForDownloading == self.translator {
                                DispatchQueue.main.async {
                                    label.removeFromSuperview()
                                    let translatedDisplayResult = strongSelf.getTextView(transformedRect, result!)
                                    
                                    let label = translatedDisplayResult.1
                                    label.backgroundColor = .black
                                    
                                    let pageView = strongSelf.getPageView(at: pageViewIndex)
                                    pageView.addSubview(label)
                                    translateResults[index].1 = result!
                                    
                                    if (index == (displayResults.count - 1)) {
                                        print("[BookReaderVC.translate] Reached \(index) translated item, saving results to CoreData.")
                                        let bookPage = strongSelf.bookPageViewController.viewControllers?.first as! BookPage
                                        bookPage.delegate?.saveTranslationsToCoreData(at: pageViewIndex, on: pageNumber, translationsResult: translateResults)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func translateOnline(_ displayResults: [(CGRect, UITextView, String)], at pageViewIndex: Int, on pageNumber: Int) {
        let from = comic?.inputLanguage
        let to = comic?.lastOutputLanguage ?? "none"
        guard to != "none" else {
            print("will not translate when outputLanguage:\(to)")
            return
        }
        updateTranslatorOptions()
        var translateResults:[(CGRect, String)] = displayResults.map { ($0.0, $0.2) }
        
        weak var weakSelf = self
        
        DispatchQueue.global(qos: .userInteractive).async {
            for (index,(transformedRect, label, textString)) in displayResults.enumerated() {
                let text = textString.replacingOccurrences(of: "\n", with: " ")
                guard let strongSelf = weakSelf else {
                    print("Self is nil!")
                    return
                }
                var uri = "https://translate.goo";
                uri += "gleapis.com/transl";
                uri += "ate_a";
                uri += "/singl";
                uri += "e?client=gtx&sl=" + (from ?? "auto") + "&tl=" + to + "&dt=t" + "&ie=UTF-8&oe=UTF-8&otf=1&ssel=0&tsel=0&kc=7&dt=at&dt=bd&dt=ex&dt=ld&dt=md&dt=qca&dt=rw&dt=rm&dt=ss&q=";
                
                uri += text.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
                
                var request = URLRequest(url: URL(string: uri)!)
                request.httpMethod = "GET"
                request.setValue(strongSelf.userAgents[Int.random(in: 0 ..< strongSelf.userAgents.count)], forHTTPHeaderField: "User-Agent")
                let session = URLSession.shared
                let task = session.dataTask(with: request, completionHandler: { data, response, error in
                    if let _ = error {
                        print("Error while attempting translation online: \(error?.localizedDescription ?? "None")")
                    } else if let data = data {
                        let json = try? JSONSerialization.jsonObject(with: data, options: []) as? NSArray
                        if let json = json, json.count > 0 {
                            let array = json[0] as? NSArray ?? NSArray()
                            var result: String = ""
                            for i in 0 ..< array.count {
                                let blockText = array[i] as? NSArray
                                if let blockText = blockText, blockText.count > 0 {
                                    let value = blockText[0] as? String
                                    if let value = value, value != "null" {
                                        result += value
                                    }
                                }
                            }
                            let detectedLanguage = json[2] as? String
                            let translationResult = result.replacingOccurrences(of: "\n", with: " ")
                            
                            var fromLang: String?
                            if let lang = detectedLanguage {
                                fromLang = lang
                            } else if let lang = from {
                                fromLang = lang
                            }
                            if let fromLang = fromLang {
                                let index = fromLang.index(fromLang.startIndex, offsetBy: 2)
                                let fromLangCode = String(fromLang.prefix(upTo: index))
                                
                                if fromLangCode != from {
                                    strongSelf.comic?.inputLanguage = String(fromLang.prefix(upTo: index))
                                }
                            }
                            
                            translateResults[index].1 = result
                            DispatchQueue.main.async {
                                label.removeFromSuperview()
                                let translatedDisplayResult = strongSelf.getTextView(transformedRect, translationResult)
                                
                                let label = translatedDisplayResult.1
                                label.backgroundColor = .black
                                
                                let pageView = strongSelf.getPageView(at: pageViewIndex)
                                pageView.addSubview(label)
                                
                                if (index == (displayResults.count - 1)) {
                                    print("[BookReaderVC.translate] Reached \(index) translated item, saving results to CoreData.")
                                    let bookPage = strongSelf.bookPageViewController.viewControllers?.first as! BookPage
                                    bookPage.delegate?.saveTranslationsToCoreData(at: pageViewIndex, on: pageNumber, translationsResult: translateResults)
                                }
                            }
                        } else {
                            print("Error while translating online: \(error?.localizedDescription ?? "none")")
                        }
                    }
                })
                task.resume()
            }
        }
    }
    
    func updateLanguageDetectRequestParameters() {
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesCPUOnly = false
        
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
