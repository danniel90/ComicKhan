//
//  BookReaderVC+TextProcessing.swift
//  wutComicReader
//
//  Created by Daniel on 9/3/22.
//

import UIKit
import MLKit

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
                let label = displayResult.1
                pageView.addSubview(label)
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
        label.textAlignment = .left
        label.contentInset = UIEdgeInsets(top: -7.0,left: 0.0,bottom: 0,right: 0.0);//https://stackoverflow.com/a/39848685
        label.font = .systemFont(ofSize: 200)
        label.isUserInteractionEnabled = true
        label.isSelectable = false
        label.isEditable = false
        label.isScrollEnabled = true
        label.scrollRangeToVisible(NSRange(location: 0,length: 0))
        label.setContentOffset(CGPoint(x: 0,y: 0), animated: false)
        label.addGestureRecognizer(getLongPressGestureRecognizer())
        label.addGestureRecognizer(getTextViewPanningRecognizer())
        self.updateTextFont(label)
        return (transformedRect, label, text)
    }
    
    func getLongPressGestureRecognizer() -> UILongPressGestureRecognizer {
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.textViewLongPressed))
        longPressGestureRecognizer.minimumPressDuration = 1
        return longPressGestureRecognizer
    }
    
    
    func getTextViewPanningRecognizer() -> UIPanGestureRecognizer {
        let textViewPanningRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.textViewPanning))
        return textViewPanningRecognizer
    }
    
    @objc func textViewLongPressed(_ sender: UILongPressGestureRecognizer) {
        print("textViewLongPressed")
        // Activate textviews: 0. Select individual 1.Select All 2. Deselect All 3. Refresh 4. Delete 5. pseudo rich text editor 5.1 font sizes 5.2 locations 6. Undo 7. Done
        switch sender.state {
        case .began:
            if let textView = sender.view as? UITextView {
                textView.backgroundColor = .systemBlue
                textView.layer.borderWidth = 2
                textView.layer.borderColor = UIColor.red.cgColor
                
                let locationPageview = sender.location(in: textView.superview)
                self.firstLocationPageView = locationPageview
                
            }
        case .changed:
            if let textView = sender.view as? UITextView {
                let locationPageview = sender.location(in: textView.superview)
//                print("Moved to: \(locationTextView)")
                let frame = textView.frame
                let quadrantWidth = frame.width / 2
                let quadrantHeight = frame.height / 2
                
                let topLeftQuadrantOrigin = frame.origin
                let topRightQuadrantOrigin = CGPoint(x: topLeftQuadrantOrigin.x + quadrantWidth, y: topLeftQuadrantOrigin.y)
                let bottomLeftQuadrantOrigin = CGPoint(x: topLeftQuadrantOrigin.x, y: topLeftQuadrantOrigin.y + quadrantHeight)
                let bottomRightQuadrantOrigin = CGPoint(x: bottomLeftQuadrantOrigin.x + quadrantWidth, y: topLeftQuadrantOrigin.y + quadrantHeight)
                
                
                let bottomLeftQuadrant = CGRect(x: bottomLeftQuadrantOrigin.x, y: bottomLeftQuadrantOrigin.y, width: quadrantWidth, height: quadrantHeight)
                let bottomRightQuadrant = CGRect(x: bottomRightQuadrantOrigin.x, y: bottomRightQuadrantOrigin.y, width: quadrantWidth, height: quadrantHeight)
                let topLeftQuadrant = CGRect(x: topLeftQuadrantOrigin.x, y: topLeftQuadrantOrigin.y, width: quadrantWidth, height: quadrantHeight)
                let topRightQuadrant = CGRect(x: topRightQuadrantOrigin.x, y: topRightQuadrantOrigin.y, width: quadrantWidth, height: quadrantHeight)
                
                guard let firstLocationPageView = self.firstLocationPageView else { return }
                let translation = CGPoint(x: locationPageview.x - firstLocationPageView.x, y: locationPageview.y - firstLocationPageView.y)
                var newFrame = frame
                if bottomLeftQuadrant.contains(locationPageview) {
                    print("bottomLeftQuadrant contains LongPress")
                    //left
                    newFrame.origin.x += translation.x
                    newFrame.size.width -= translation.x
                    //bottom
                    newFrame.size.height += translation.y
                } else if bottomRightQuadrant.contains(locationPageview) {
                    print("bottomRightQuadrant contains LongPress")
                    //right
                    newFrame.size.width += translation.x
                    //bottom
                    newFrame.size.height += translation.y
                } else if topLeftQuadrant.contains(locationPageview) {
                    print("topLeftQuadrant contains LongPress")
                    //left
                    newFrame.origin.x += translation.x
                    newFrame.size.width -= translation.x
                    //top
                    newFrame.origin.y += translation.y
                    newFrame.size.width -= translation.y
                } else if topRightQuadrant.contains(locationPageview) {
                    print("topRightQuadrant contains LongPress")
                    //right
                    newFrame.size.width += translation.x
                    //top
                    newFrame.origin.y += translation.y
                    newFrame.size.width -= translation.y
                } else if frame.contains(locationPageview) {
                    print("frame contains LongPress")
                } else {
                    print("LongPress Quadrant missing")
                }
                
                textView.frame = newFrame
                self.firstLocationPageView = locationPageview
            }
        case .ended:
            if let textView = sender.view as? UITextView {
                textView.backgroundColor = .black
                textView.layer.borderWidth = 0
                textView.layer.borderColor = UIColor.black.cgColor
                self.updateTextFont(textView)
            }
        default:
            return
        }
    }
    
    @objc func textViewPanning(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began:
            if let textView = sender.view as? UITextView {
                textView.backgroundColor = textView.backgroundColor?.withAlphaComponent(0.5)
            }
        case .changed:
            if let textView = sender.view as? UITextView {
                let translation = sender.translation(in: textView.superview)
                textView.center = CGPoint(x: textView.center.x + translation.x, y: textView.center.y + translation.y)
                sender.setTranslation(CGPoint.zero, in: textView.superview)
            }
        case .ended:
            if let textView = sender.view as? UITextView {
                textView.backgroundColor = textView.backgroundColor?.withAlphaComponent(1)
            }
        default:
            print(sender.state.rawValue)
            return
        }
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
}
