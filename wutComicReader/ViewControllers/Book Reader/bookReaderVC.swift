//
//  bookReaderVC.swift
//  wutComicReader
//
//  Created by Shayan on 6/25/19.
//  Copyright © 2019 wutup. All rights reserved.
//

import UIKit


protocol BottomBarDelegate {
    func newPageBeenSet(pageNumber: Int)
}

protocol TopBarDelegate {
    func dismissViewController()
}

struct ConstraintsForSizeClasses {
    var sharedConstaints: [NSLayoutConstraint] = []
    
    var CVCHConstaints: [NSLayoutConstraint] = []
    var RVRHConstaints: [NSLayoutConstraint] = []
    var CVRHConstaints: [NSLayoutConstraint] = []
    var RVCHConstaints: [NSLayoutConstraint] = []
    
    var compactConstaints: [NSLayoutConstraint] = []
    var regularConstraints: [NSLayoutConstraint] = []
    
}

class BookReaderVC: UIViewController {
    
    //MARK:- Variables
    
    var comic : Comic? {
        didSet{
            guard let _ = comic else { return }
//            topBar.titleLabel.text = comic?.name
        }
    }
    
    
    var bookIndexInLibrary: IndexPath?
    
    var lastViewedPage : Int?
    var menusAreAppeard: Bool = false
    
    var bookPageViewController : UIPageViewController!
    var bookSingleImages : [ComicImage] = []
    var bookDoubleImages : [(ComicImage? , ComicImage?)] = []
    var bookPages: [BookPage] = []
    
    var thumbnailImages: [ComicImage] = []
    
    
    private var compactConstaitns: [NSLayoutConstraint] = []
    private var regularConstraint: [NSLayoutConstraint] = []
    private var sharedConstraints: [NSLayoutConstraint] = []
    
    var deviceIsLandscaped: Bool = UIDevice.current.orientation.isLandscape {
        didSet{
            setPageViewControllers()
            if let page = lastViewedPage {
                setLastViewedPage(toPageWithNumber: page, withAnimate: false)
            }
        }
    }
    
    
    
    //MARK:- UI Variables
    
    lazy var bottomBar: BottomBar = {
       let bar = BottomBar()
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    lazy var bottomBarConstraints = ConstraintsForSizeClasses()
    
    lazy var topBar: TopBar = {
        let view = TopBar()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    lazy var topBarConstraint = ConstraintsForSizeClasses()
    
    //this used for fill the space between topBar and top device edge in iphone X
    lazy var topBarBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .appSystemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override var prefersStatusBarHidden: Bool {
        return !menusAreAppeard
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIDevice.current.orientation.isLandscape ?  .lightContent : .default
    }
    
    //MARK:- Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPageController()
        initSinglePageThumbnails()
        
        disappearMenus(animated: false)
        
        addGestures()
        setupDesign()
        
        
        bottomBar.thumbnailDelegate = self
        bottomBar.delegate = self
        bottomBar.comicPagesCount = comic?.imageNames?.count ?? 1
        topBar.delegate = self
        topBar.title = comic?.name
        
        
        let LastpageNumber = (comic?.lastVisitedPage) ?? 0
        setLastViewedPage(toPageWithNumber: Int(LastpageNumber), withAnimate: true)
        
        deviceIsLandscaped = UIDevice.current.orientation.isLandscape
        
    }
    
    
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        deviceIsLandscaped = UIDevice.current.orientation.isLandscape
        if deviceType == .iPad {
            layoutWith(traitCollection: UIScreen.main.traitCollection)
        }
//        
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
         layoutWith(traitCollection: UIScreen.main.traitCollection)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        let LastpageNumber = (comic?.lastVisitedPage) ?? 0
        setLastViewedPage(toPageWithNumber: Int(LastpageNumber), withAnimate: true)
    }
    
    
    
    func setupDesign(){
        
        view.addSubview(bottomBar)
        
        bottomBarConstraints.sharedConstaints.append(contentsOf: [
            bottomBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        
        let larg = view.bounds.width > view.bounds.height ? view.bounds.width : view.bounds.height
        let short = view.bounds.width > view.bounds.height ? view.bounds.height : view.bounds.width
        
        bottomBarConstraints.RVRHConstaints.append(contentsOf: [
            bottomBar.widthAnchor.constraint(equalToConstant: larg / 2),
            bottomBar.heightAnchor.constraint(equalToConstant: short / 3),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor , constant: -30)
        ])
        
        bottomBarConstraints.CVCHConstaints.append(contentsOf: [
            bottomBar.widthAnchor.constraint(equalToConstant: (larg * 2) / 3),
            bottomBar.heightAnchor.constraint(equalToConstant: short / 2),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor , constant: -20)
        ])
        
        bottomBarConstraints.RVCHConstaints.append(contentsOf: [
            bottomBar.widthAnchor.constraint(equalToConstant: short),
            bottomBar.heightAnchor.constraint(equalToConstant: larg / 3.8),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor , constant: 0)
        ])
        
        bottomBarConstraints.CVRHConstaints.append(contentsOf: [
            bottomBar.widthAnchor.constraint(equalToConstant: larg / 2),
            bottomBar.heightAnchor.constraint(equalToConstant: short / 2),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor , constant: -20)
        ])
        
        
        
        view.addSubview(topBar)
        let topBarHeight = CGFloat(50)
        
        topBarConstraint.sharedConstaints.append(contentsOf: [
            topBar.leftAnchor.constraint(equalTo: view.leftAnchor),
            topBar.rightAnchor.constraint(equalTo: view.rightAnchor),
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0)
        ])
        
        topBarConstraint.compactConstaints.append(
            topBar.heightAnchor.constraint(equalToConstant: short / 5)
        )
        
        topBarConstraint.regularConstraints.append(
            topBar.heightAnchor.constraint(equalToConstant: topBarHeight)
        )
        
        
        NSLayoutConstraint.activate(topBarConstraint.sharedConstaints)
        NSLayoutConstraint.activate(bottomBarConstraints.sharedConstaints)
        
        layoutWith(traitCollection: UIScreen.main.traitCollection)
        
        view.addSubview(topBarBackgroundView)
        topBarBackgroundView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        topBarBackgroundView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        topBarBackgroundView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        topBarBackgroundView.bottomAnchor.constraint(equalTo: topBar.topAnchor).isActive = true
//        view.sendSubviewToBack(topBarBackgroundView)
        
    }
    
    func layoutWith(traitCollection: UITraitCollection) {
        let horizontal = traitCollection.horizontalSizeClass
        let vertical = traitCollection.verticalSizeClass
        
        //bottomBar setup
        
        NSLayoutConstraint.deactivate(bottomBarConstraints.CVCHConstaints)
        NSLayoutConstraint.deactivate(bottomBarConstraints.CVRHConstaints)
        NSLayoutConstraint.deactivate(bottomBarConstraints.RVCHConstaints)
        NSLayoutConstraint.deactivate(bottomBarConstraints.RVRHConstaints)
        
        if horizontal == .compact && vertical == .compact {
            NSLayoutConstraint.activate(bottomBarConstraints.CVCHConstaints)
        }else if horizontal == .compact && vertical == .regular {
            NSLayoutConstraint.activate(bottomBarConstraints.RVCHConstaints)
        }else if horizontal == .regular && vertical == .compact {
            NSLayoutConstraint.activate(bottomBarConstraints.CVRHConstaints)
        }else {
            NSLayoutConstraint.activate(bottomBarConstraints.RVRHConstaints)
        }
        
        //topBar setup
        
        NSLayoutConstraint.deactivate(topBarConstraint.compactConstaints)
        NSLayoutConstraint.deactivate(topBarConstraint.regularConstraints)
        
        if UIDevice.current.orientation.isLandscape {
            NSLayoutConstraint.activate(topBarConstraint.compactConstaints)
        }else {
            NSLayoutConstraint.activate(topBarConstraint.regularConstraints)
        }
        
        //topBarBackground setup
        
        topBarBackgroundView.backgroundColor = UIDevice.current.orientation.isLandscape ? UIColor.black.withAlphaComponent(0.7) : .appSystemBackground
        
    }
    
    func addGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleMenusGestureTapped))
        tapGesture.numberOfTapsRequired = 1
        bookPageViewController.view.addGestureRecognizer(tapGesture)
        
        let doubletapGesture = UITapGestureRecognizer(target: self, action: #selector(zoomBookCurrentPage))
        doubletapGesture.numberOfTapsRequired = 2
        bookPageViewController.view.addGestureRecognizer(doubletapGesture)
        
        tapGesture.require(toFail: doubletapGesture)
        
    }
    
    func setLastViewedPage(toPageWithNumber number: Int, withAnimate animate: Bool = true) {
        
        let bookPage = bookPageViewController.viewControllers?.first as! BookPage
        let page1Number = bookPage.image1?.pageNumber
        let page2Number = bookPage.image2?.pageNumber
        
        if page1Number != number && page2Number != number {
            
            let pendingPage = bookPages.first {
                return $0.image1?.pageNumber == number || $0.image2?.pageNumber == number
            }
            
            if let _ = pendingPage {
//                var diraction: UIPageViewController.NavigationDirection {
//                    return page1Number < number ? .reverse : .forward
//                }
            bookPageViewController.setViewControllers([pendingPage!], direction: .forward, animated: animate, completion: nil)
            }
            
        }
        
        //update bottomBar variables
        if number != bottomBar.currentPage {
            bottomBar.currentPage = number
        }
        
        //update comic.lastvisitedPage
        lastViewedPage = number
        if let _ = lastViewedPage {
            comic?.lastVisitedPage = Int16(lastViewedPage!)
        }
        
    }
    
//    func updateBookReaderValues(){
//
//        let lastVisitedPage = Int(comic?.lastVisitedPage ?? 0)
//        let lastViewedBookPageIndex: Int?
//
//        if deviceIsLandscaped {
//            lastViewedBookPageIndex = doublePageIndexForPage(withNumber: lastVisitedPage)
//        }else{
//            lastViewedBookPageIndex = lastVisitedPage
//        }
//
//
//
//        if let _ = lastViewedBookPageIndex {
////            thumbnailCollectionView.selectItem(at: IndexPath(row: lastViewedBookPageIndex!, section: 0), animated: false, scrollPosition: .centeredHorizontally)
//            bookPageViewController.setViewControllers([bookPages[lastViewedBookPageIndex!]], direction: .forward, animated: false, completion: nil)
//
////            pageSlider.minimumValue = 1.0
////            pageSlider.setValue(Float(lastViewedBookPageIndex!), animated: false)
////            pageSlider.maximumValue = Float(bookPages.count)
//
////            comicPageNumberLabel.text = "\(bookSingleImages.count)"
////            configureCurrentPageLabelText(forBookPageIndex: lastViewedBookPageIndex!)
//
//
//
//
//        }
//    }
    
    
    @objc func zoomBookCurrentPage() {
        let currentPage = bookPageViewController.viewControllers?.first as? BookPage
        currentPage?.zoomWithDoubleTap()
        
    }
    
    //MARK:- Menues Appearing Handeling
    
    @objc func toggleMenusGestureTapped() {
        if menusAreAppeard {
            disappearMenus(animated: true)
        }else{
            appearMenus(animated: true)
        }
    }
    
    
    
    func disappearMenus(animated: Bool) {
        menusAreAppeard = false
        self.setNeedsStatusBarAppearanceUpdate()
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                self.topBar.alpha = 0.0
                self.topBarBackgroundView.alpha = 0
                self.bottomBar.transform = CGAffineTransform(translationX: 0, y: self.bottomBar.frame.height + 30)
                self.bottomBar.alpha = 0.1
            }, completion: nil)
        }else{
            topBar.alpha = 0.0
            topBarBackgroundView.alpha = 0
            bottomBar.transform = CGAffineTransform(translationX: 0, y: bottomBar.frame.height + 30)
            bottomBar.alpha = 0.0
        }
    }
    
    func appearMenus(animated: Bool) {
        menusAreAppeard = true
        self.setNeedsStatusBarAppearanceUpdate()
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                self.topBar.alpha = 1
                self.bottomBar.transform = CGAffineTransform(translationX: 0, y: 0)
                self.bottomBar.alpha = 1
                self.topBarBackgroundView.alpha = 1
            }, completion: nil)
        }else{
            topBar.alpha = 1
            topBarBackgroundView.alpha = 1
            bottomBar.transform = CGAffineTransform(translationX: 0, y: 0)
            bottomBar.alpha = 1
           
        }
        //this shouldn't be there actually but idk wherever else i can make bottom bar collection view scroll
        let LastpageNumber = (comic?.lastVisitedPage) ?? 0
        bottomBar.currentPage = Int(LastpageNumber)
    }
    
    
    
}

extension BookReaderVC: TopBarDelegate, BottomBarDelegate {
    func dismissViewController() {
        
        if let page = lastViewedPage {
            
            comic?.lastVisitedPage = Int16(page)
            let context = AppFileManager().managedContext
            try? context?.save()
        }
        NotificationCenter.default.post(name: .reloadLibraryAtIndex, object: bookIndexInLibrary)
        dismiss(animated: false, completion: nil)
        
    }
    
    func newPageBeenSet(pageNumber: Int) {
        setLastViewedPage(toPageWithNumber: pageNumber)
    }
    
    
}


