//
//  bookReaderVC.swift
//  wutComicReader
//
//  Created by Shayan on 6/25/19.
//  Copyright © 2019 wutup. All rights reserved.
//

import UIKit
import Combine
import MLKit
import MLImage


protocol TopBarDelegate: AnyObject {
    func dismissViewController()
    func BookTranslateSettingsTapped()
}

extension BookReaderVC: BookPageDelegate {
    func saveTranslationsToCoreData(at pageViewIndex: Int, on page: Int, translationsResult: [(CGRect, String)]) {
        if translationsResult.count > 0 {
            guard let language = comic?.lastOutputLanguage else {
                return
            }

            try? dataService.saveTranslationsToCoreData(comic: comic!, translationsResult: translationsResult, with: language, on: Int16(page))
        }
    }
    
    func imageDidChange(at pageViewIndex: Int) {
        removeDetectionAnnotations(at: pageViewIndex)
        
        let pageView = self.getPageView(at: pageViewIndex)
        guard let image = pageView.image else { return }
        guard comic?.inputLanguage != nil && comic?.inputLanguage != "none" else { return }
        guard let pageNumber = bottomBar.currentPage else { return }
        
        //try fetch from store
        let translationsFromCoreData = fetchTranslationsFromCoreData(on: pageNumber)
        if translationsFromCoreData.count > 0 {
            let pageView = self.getPageView(at: pageViewIndex)

            for (transformedRect, translatedText) in translationsFromCoreData {
                let displayResult = self.getTextView(transformedRect, translatedText)
                let label = displayResult.1
                label.backgroundColor = .black
                pageView.addSubview(label)
            }

            return
        }
        //if fetch empty
        //TODO: detect
        var textRecognizer: TextRecognizer
        var languageOptions: CommonTextRecognizerOptions

        let language = comic?.inputLanguage
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
            return
        case nil:
            return
        case "detect":
            print("detect input language selected for translate")
            return
        default:
            languageOptions = TextRecognizerOptions()

        }
        textRecognizer = TextRecognizer.textRecognizer(options: languageOptions)

        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation
        DispatchQueue.global(qos: .userInitiated).async {
            self.process(visionImage, with: textRecognizer, at: pageViewIndex)
        }
    }
}

extension BookReaderVC {
    // MARK: - Private
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
    
    private func getPageView(at pageViewIndex: Int) -> UIImageView {
        let bookPage = self.bookPageViewController.viewControllers?.first as! BookPage
        var pageView: UIImageView
        
        if (pageViewIndex == 1) {
            pageView = bookPage.pageImageView1
        } else {
            pageView = bookPage.pageImageView2
        }
        return pageView
    }
    
    private func removeDetectionAnnotations(at pageViewIndex: Int) {
        let pageView = self.getPageView(at: pageViewIndex)
        
        for annotationView in pageView.subviews {
            annotationView.removeFromSuperview()
        }
    }

    private func transformMatrix(_ pageView: UIImageView) -> CGAffineTransform {
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
    
    private func process(_ visionImage: VisionImage, with textRecognizer: TextRecognizer?, at pageViewIndex: Int) {
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
                strongSelf.translateOnDevice(displayResults, at: pageViewIndex)
                //TODO: ENABLE ONLINE MODE TRANSLATE
            default:
                print("ONLINE MODE PENDING")
                return
            }
        }
    }
    
    func getTextView(_ transformedRect: CGRect, _ text: String) -> (CGRect, UITextView, String) {
        let label = UITextView(frame: transformedRect)
        label.text = text
        label.font = .systemFont(ofSize: 200)
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
    
    private func translateOnDevice(_ displayResults: [(CGRect, UITextView, String)], at pageViewIndex: Int) {
        let inputLanguage = comic?.inputLanguage ?? "none"
        let outputLanguage = comic?.lastOutputLanguage ?? "none"
        guard inputLanguage != "none" && outputLanguage != "none" else {
            print("will not translate when inputLanguage:\(inputLanguage) & outputLanguage:\(outputLanguage)")
            return
        }
        updateTranslatorOptions()
        
        weak var weakSelf = self
        let translatorForDownloading = self.translator!
        
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
                                bookPage.delegate?.saveTranslationsToCoreData(at: pageViewIndex, on: bookPage.pageNumber!, translationsResult: translateResults)
                            }
                        }
                    }
                }
            }
        }
    }
}

final class BookReaderVC: DynamicConstraintViewController {
    
    //MARK: Variables
    private(set) var dataService: DataService = Cores.main.dataService
    var translator: Translator!
    let locale = Locale.current
    
    var comic : Comic? {
        didSet{
            guard let _ = comic else { return }
        }
    }
    

    
    var lastViewedPage : Int?
    var menusAreAppeard: Bool = false
    
    
    var bookSingleImages : [ComicImage] = []
    var bookDoubleImages : [(ComicImage? , ComicImage?)] = []
    var bookPages: [BookPage] = []
    
    var thumbnailImages: [ComicImage] = []
    
    
    private var compactConstaitns: [NSLayoutConstraint] = []
    private var regularConstraint: [NSLayoutConstraint] = []
    private var sharedConstraints: [NSLayoutConstraint] = []
    
    var comicReadingProgressDidChanged: ((_ comic: Comic, _ lastPageHasRead: Int) -> Void)?
    
    var cancellables = Set<AnyCancellable>()
    
    
    //MARK: UI Variables
    
    private lazy var bottomBar: BottomBar = {
        let bar = BottomBar()
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    
    private lazy var topBar: TopBar = {
        let view = TopBar()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var settingBar: ReaderSettingVC = {
        let vc = ReaderSettingVC(settingDelegate: self)
        vc.view.layer.cornerRadius = 20
        vc.view.clipsToBounds = true
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        return vc
    }()
    
    private lazy var BookTranslateSettingsBar: BookTranslateSettingsVC = {
        let vc = BookTranslateSettingsVC(settingDelegate: self, comic: self.comic)
        vc.view.layer.cornerRadius = 20
        vc.view.clipsToBounds = true
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        return vc
    }()
    
    private lazy var blurView: UIVisualEffectView = {
        let view = UIVisualEffectView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    //this used for fill the space between topBar and top device edge in iphone X
    //FIXME: You don't need this!
    lazy var topBarBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .appBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    var bookPageViewController : UIPageViewController!
    var currentPage: BookPage? {
        bookPageViewController.viewControllers?.first as? BookPage
    }
    
    private lazy var guideView: ReaderGuideView = {
        let view = ReaderGuideView()
        return view
    }()
    
    override var prefersStatusBarHidden: Bool {
        return !menusAreAppeard
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIDevice.current.orientation.isLandscape ?  .lightContent : .default
    }
    
    //MARK: Functions
    
    func updateTranslatorOptions() {
        let inputLanguage = comic?.inputLanguage ?? "en"
        let outputLanguage = comic?.lastOutputLanguage ?? "es"
        
        let options = TranslatorOptions(sourceLanguage: TranslateLanguage(rawValue: inputLanguage), targetLanguage: TranslateLanguage(rawValue: outputLanguage))
        translator = Translator.translator(options: options)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPageController(pageMode: AppState.main.readerPageMode)
        
        disappearMenus(animated: false)
        
        addGestures()
        setupDesign()
        addGuideViewIfNeeded()
        observeAppStateChanges()
        
        bottomBar.thumbnailsDataSource = self
        bottomBar.thumbnailDelegate = self
        bottomBar.delegate = self
        bottomBar.comicPagesCount = comic?.imageNames?.count ?? 1
        topBar.delegate = self
        topBar.title = comic?.name
        
        updateTranslatorOptions()
        
        
        let LastpageNumber = (comic?.lastVisitedPage) ?? 1
        setLastViewedPage(toPageWithNumber: Int(LastpageNumber), withAnimate: true)
        
    }
    
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bottomBar.invalidateThimbnailCollectionViewLayout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    func setupDesign(){
        view.addSubview(bottomBar)
        view.addSubview(topBar)
        view.addSubview(topBarBackgroundView)
        
        
        setConstraints(shared: [
            topBar.leftAnchor.constraint(equalTo: view.leftAnchor),
            topBar.rightAnchor.constraint(equalTo: view.rightAnchor),
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            bottomBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            topBarBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            topBarBackgroundView.leftAnchor.constraint(equalTo: view.leftAnchor),
            topBarBackgroundView.rightAnchor.constraint(equalTo: view.rightAnchor),
            topBarBackgroundView.bottomAnchor.constraint(equalTo: topBar.topAnchor)
            
            
        ])
        
        setConstraints(
            CVCH: [
                bottomBar.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
                bottomBar.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4),
                bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor , constant: -20)
            ], RVCH: [
                bottomBar.widthAnchor.constraint(equalTo: view.widthAnchor),
                bottomBar.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.3),
                bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor , constant: 0)
            ], CVRH: [
                bottomBar.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
                bottomBar.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4),
                bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor , constant: -20)
            ], RVRH: [
                bottomBar.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
                bottomBar.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.3).withLowPiority(),
                bottomBar.heightAnchor.constraint(lessThanOrEqualToConstant: 280).withHighPiority(),
                bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor , constant: -30)
            ])
        setupDynamicLayout()
        
    }
    
    
    func updateTopBarBackground() {
        topBarBackgroundView.backgroundColor = UIDevice.current.orientation.isLandscape ? UIColor.black.withAlphaComponent(0.7) : .appBackground
    }
    
    func addGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleMenusGestureTapped))
        tapGesture.numberOfTapsRequired = 1
        bookPageViewController.view.addGestureRecognizer(tapGesture)
        
        let doubletapGesture = ZoomGestureRecognizer(target: self, action: #selector(zoomBookCurrentPage(_:)))
        doubletapGesture.numberOfTapsRequired = 2
        bookPageViewController.view.addGestureRecognizer(doubletapGesture)
        
        tapGesture.require(toFail: doubletapGesture)
        
    }
    
    private func addGuideViewIfNeeded() {
        if AppState.main.readerPresentForFirstTime() {
            
            guideView.delegate = self
            
            view.addSubview(guideView)
            
            guideView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
            guideView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
            guideView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            guideView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            
        }
    }
    
    
    func setLastViewedPage(toPageWithNumber number: Int, withAnimate animate: Bool = true, force: Bool = false) {
        
        //if numbers where not the same, set the bookpages in pageviewcontroller
        //if force is true set them any way
        let page1Number = currentPage?.image1?.pageNumber
        let page2Number = currentPage?.image2?.pageNumber
        
        if force || (page1Number != number && page2Number != number) {
            
            let pendingPage = bookPages.first {
                return $0.image1?.pageNumber == number || $0.image2?.pageNumber == number
            }
            
            if let _ = pendingPage {
                bookPageViewController.setViewControllers([pendingPage!], direction: .forward, animated: animate, completion: nil)
            }
            
        }
        
        //update bottomBar variables
        if number != bottomBar.currentPage {
            bottomBar.currentPage = number
        }
        
        //update comic.lastvisitedPage
        //FIXME: In double splash pages the number is smh NIL and not getting stored as the lastPage
        lastViewedPage = number
        if let _ = lastViewedPage {
            comic?.lastVisitedPage = Int16(lastViewedPage!)
        }
        
    }
    
    private func observeAppStateChanges() {
        AppState.main.$readerTheme
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .filter { $0 != nil }
            .sink { [weak self] theme in
                self?.currentPage?.setUpTheme(theme!)
            }.store(in: &cancellables)
        
        AppState.main.$readerPageMode
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .filter { $0 != nil }
            .sink { [weak self] pageMode in
                self?.configureBookPages(pageMode: pageMode!)
                if let page = self?.lastViewedPage {
                    self?.setLastViewedPage(toPageWithNumber: page, withAnimate: false, force: true)
                }
                self?.currentPage?.setUpPageMode(pageMode!)
                
            }.store(in: &cancellables)
    }
    
    @objc func zoomBookCurrentPage(_ sender: ZoomGestureRecognizer) {
        guard let point = sender.point else { return }
        currentPage?.zoomWithDoubleTap(toPoint: point)
        
    }
    
    //MARK: Menues Appearing Handeling
    
    @objc func toggleMenusGestureTapped() {
        if menusAreAppeard {
            disappearMenus(animated: true)
        }else{
            appearMenus(animated: true)
        }
    }
    
    
    
    func disappearMenus(animated: Bool) {
        menusAreAppeard = false
        
        func changes() {
            topBar.alpha = 0.0
            topBarBackgroundView.alpha = 0
            bottomBar.transform = CGAffineTransform(translationX: 0, y: bottomBar.frame.height + 30)
            bottomBar.alpha = 0.0
        }
        
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                changes()
            }, completion: { _ in
                self.setNeedsStatusBarAppearanceUpdate()
            })
        }else{
            changes()
        }
    }
    
    func appearMenus(animated: Bool) {
        menusAreAppeard = true
        self.setNeedsStatusBarAppearanceUpdate()
        
        func changes() {
            self.topBar.alpha = 1
            self.bottomBar.transform = CGAffineTransform(translationX: 0, y: 0)
            self.bottomBar.alpha = 1
            self.topBarBackgroundView.alpha = 1
        }
        
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                changes()
            }, completion: { _ in
            })
        }else{
            changes()
        }
        //FIXME: this shouldn't be there actually but idk wherever else i can make bottom bar collection view scroll
        let LastpageNumber = (comic?.lastVisitedPage) ?? 0
        bottomBar.currentPage = Int(LastpageNumber)
        
        
    }
    
    
    
    
    
}

extension BookReaderVC: TopBarDelegate, BottomBarDelegate {
    
    func dismissViewController() {
        comicReadingProgressDidChanged?(comic!, lastViewedPage ?? 0)
        
        bottomBar.delegate = nil
        topBar.delegate = nil
        
        dismiss(animated: false, completion: nil)
        
    }
    
    func newPageBeenSet(pageNumber: Int) {
        setLastViewedPage(toPageWithNumber: pageNumber)
    }
    
    
    
    
}

extension BookReaderVC: ReaderSettingVCDelegate {
    func settingTapped() {
        presentSettingBar()
    }
    
    func doneButtonTapped() {
        dismissSettingBar()
    }
    
    func presentSettingBar() {
        blurView.effect = UIBlurEffect(style: .systemThinMaterial)
        
        view.addSubview(blurView)
        blurView.alpha = 0
        
        addChild(settingBar)
        view.addSubview(settingBar.view)
        settingBar.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            settingBar.view.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            settingBar.view.leftAnchor.constraint(equalTo: bottomBar.leftAnchor),
            settingBar.view.rightAnchor.constraint(equalTo: bottomBar.rightAnchor),
            settingBar.view.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor),
            
            blurView.leftAnchor.constraint(equalTo: view.leftAnchor),
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blurView.rightAnchor.constraint(equalTo: view.rightAnchor),
        ])
        
        let shifting = settingBar.view.bounds.height + 40
        settingBar.view.transform = CGAffineTransform(translationX: 0, y: shifting)
        
        UIView.animate(withDuration: 1, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1, options: .curveEaseIn) { [weak self] in
            self?.settingBar.view.transform = CGAffineTransform(translationX: 0, y: 0)
            self?.blurView.alpha = 1
        } completion: { _ in}
        
    }
    
    func dismissSettingBar() {
        
        let shifting = settingBar.view.bounds.height + 40
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) { [weak self] in
            self?.settingBar.view.transform = CGAffineTransform(translationX: 0, y: shifting)
            self?.blurView.alpha = 0
        } completion: { [weak self] _ in
            self?.settingBar.willMove(toParent: nil)
            self?.settingBar.removeFromParent()
            self?.settingBar.view.removeFromSuperview()
            self?.blurView.removeFromSuperview()
        }
        
        
        
    }
}

extension BookReaderVC: BookTranslateSettingsVCDelegate {
    func BookTranslateSettingsTapped() {
        presentBookTranslateSettingsBar()
    }
    
    func doneTranslateButtonTapped() {
        dismissBookTranslateSettingsBar()
    }
    
    func presentBookTranslateSettingsBar() {
        blurView.effect = UIBlurEffect(style: .systemThinMaterial)
        
        view.addSubview(blurView)
        blurView.alpha = 0
        
        addChild(BookTranslateSettingsBar)
        view.addSubview(BookTranslateSettingsBar.view)
        BookTranslateSettingsBar.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            BookTranslateSettingsBar.view.topAnchor.constraint(equalTo: topBar.topAnchor),
            BookTranslateSettingsBar.view.leftAnchor.constraint(equalTo: bottomBar.leftAnchor),
            BookTranslateSettingsBar.view.rightAnchor.constraint(equalTo: bottomBar.rightAnchor),
            BookTranslateSettingsBar.view.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 210),
            
            blurView.leftAnchor.constraint(equalTo: view.leftAnchor),
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blurView.rightAnchor.constraint(equalTo: view.rightAnchor),
        ])
        
        let shifting = BookTranslateSettingsBar.view.bounds.height + 40
        BookTranslateSettingsBar.view.transform = CGAffineTransform(translationX: 0, y: shifting)
        
        UIView.animate(withDuration: 1, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1, options: .curveEaseIn) { [weak self] in
            self?.BookTranslateSettingsBar.view.transform = CGAffineTransform(translationX: 0, y: 0)
            self?.blurView.alpha = 1
        } completion: { _ in}
        
    }
    
    func dismissBookTranslateSettingsBar() {
        
        let shifting = BookTranslateSettingsBar.view.bounds.height + 40
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) { [weak self] in
            self?.BookTranslateSettingsBar.view.transform = CGAffineTransform(translationX: 0, y: shifting)
            self?.blurView.alpha = 0
        } completion: { [weak self] _ in
            self?.BookTranslateSettingsBar.willMove(toParent: nil)
            self?.BookTranslateSettingsBar.removeFromParent()
            self?.BookTranslateSettingsBar.view.removeFromSuperview()
            self?.blurView.removeFromSuperview()
        }
        
        
        
    }
}

extension BookReaderVC: GuideViewDelegate {
    func viewElementsDidDissappeared() {
        guideView.removeFromSuperview()
    }
    
    
}
