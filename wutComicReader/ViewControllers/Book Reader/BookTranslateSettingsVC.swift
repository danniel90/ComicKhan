//
//  BookTranslateSettingsVC.swift
//  wutComicReader
//
//  Created by Daniel on 8/31/22.
//

import Foundation
import UIKit
import MLKit

class BookTranslateSettingsVC: UINavigationController {
    let locale = Locale.current

    public var allLanguages: [TranslateLanguage] {
        get {
            TranslateLanguage.allLanguages().sorted {
                return locale.localizedString(forLanguageCode: $0.rawValue)!
                < locale.localizedString(forLanguageCode: $1.rawValue)!
            }
        }
    }
    
    public var bookTranslateSourceOptions: [String] {
        get {
            var options = allLanguages.map {
                $0.rawValue
            }
            options.insert(contentsOf: ["none", "detect"], at: 0)
            return options
        }
    }
    
    public var bookTranslateTargetOptions: [String] {
        get {
            var options = allLanguages.map {
                $0.rawValue
            }
            options.insert("none", at: 0)
            return options
        }
    }
    
    init(settingDelegate: BookTranslateSettingsVCDelegate? = nil, comic: Comic?) {
        let vc = SettingVC()
        vc.delegate = settingDelegate
        vc.comic = comic
        super.init(rootViewController: vc)
        vc.bookTranslateSourceOptions = self.bookTranslateSourceOptions
        vc.bookTranslateTargetOptions = self.bookTranslateTargetOptions
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SettingVC: UIPickerViewDataSource, UIPickerViewDelegate {
    //MARK: UIPickerViewDataSource Methods
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        var count: Int
        
        switch pickerView.tag {
        case 0:
            count = bookTranslateSourceOptions?.count ?? 0
        case 1:
            count = bookTranslateTargetOptions?.count ?? 0
        default:
            count = 0
        }
        
        return count
    }
    
    //MARK: UIPickerViewDelegate Methods
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        var pickedString: String?
        
        switch pickerView.tag {
        case 0:
            let selectedOption = bookTranslateSourceOptions?[row] ?? "none"
            if selectedOption == "none" || selectedOption == "detect" {
                pickedString = selectedOption
            } else {
                let language = locale.localizedString(forLanguageCode: selectedOption) ?? ""
                pickedString = "\(language) (\(selectedOption))"
            }
            
        case 1:
            let selectedOption = bookTranslateTargetOptions?[row] ?? "none"
            if selectedOption == "none" {
                pickedString = selectedOption
            } else {
                let language = locale.localizedString(forLanguageCode: selectedOption) ?? ""
                pickedString = "\(language) (\(selectedOption))"
            }
        default:
            pickedString = ""
        }
        
        var label = UILabel()
        if let v = view as? UILabel { label = v }
        label.font = AppState.main.font.body
        label.text =  pickedString
        label.textAlignment = .center
        return label
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        var message = "PickerView \(pickerView.tag) SelectedRow "
        
        switch pickerView.tag {
        case 0:
            message += bookTranslateSourceOptions?[pickerView.selectedRow(inComponent: 0)]  ?? "none"
        case 1:
            message += bookTranslateTargetOptions?[pickerView.selectedRow(inComponent: 0)] ?? "none"
        default:
            message += ""
        }
        
        print(message)
    }
    
    
}

protocol BookTranslateSettingsVCDelegate: AnyObject {
    func doneTranslateButtonTapped()
}

fileprivate final class SettingVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var bookTranslateSourceOptions: [String]?
    var bookTranslateTargetOptions: [String]?
    var comic : Comic? 
    private(set) var dataService: DataService = Cores.main.dataService
    let locale = Locale.current
    
    weak var delegate: BookTranslateSettingsVCDelegate?
    
    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .insetGrouped)
        view.tag = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var bookTranslateSourcePicker: UIPickerView = {
        let inputPickerView = UIPickerView(frame: .zero)
        inputPickerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        inputPickerView.tag = 0
        inputPickerView.dataSource = self
        inputPickerView.selectRow(bookTranslateSourceOptions?.firstIndex(of: comic?.inputLanguage ?? "none") ?? 0, inComponent: 0, animated: false)
        inputPickerView.delegate = self
        inputPickerView.translatesAutoresizingMaskIntoConstraints = false
        
        return inputPickerView
    }()
    
    private lazy var bookTranslateTargetPicker: UIPickerView = {
        let outputPickerView = UIPickerView(frame: .zero)
        outputPickerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        outputPickerView.tag = 1
        outputPickerView.dataSource = self
        outputPickerView.selectRow(bookTranslateTargetOptions?.firstIndex(of: comic?.lastOutputLanguage ?? "none") ?? 0, inComponent: 0, animated: false)
        outputPickerView.delegate = self
        outputPickerView.translatesAutoresizingMaskIntoConstraints = false
        
        return outputPickerView
    }()
    
    private lazy var translateModeSegmentControl: UISegmentedControl = {
        let view = UISegmentedControl(frame: .zero, actions: TranslateMode.allCases.map({ translateMode in
            return UIAction(title: translateMode.name, handler: { [weak self] _ in
                print("Translate Mode \(translateMode.rawValue) - \(translateMode.name)")
            })
        }))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var deleteDownloadedLanguagesButton: UIButton = {
        let button = UIButton(frame: .zero)
        let deleteImage = #imageLiteral(resourceName: "ic-actions-trash").withRenderingMode(.alwaysTemplate)
        button.setImage(deleteImage, for: .normal)
        button.isEnabled = false
        button.addTarget(self,
                         action: #selector(deleteDownloadedLanguagesButtonTapped),
                         for: .touchUpInside)
        return button
    }()
    
    private lazy var downloadedLanguagesTable:UITableView = {
        let downloadedLanguagesTable = UITableView(frame: .zero)
        downloadedLanguagesTable.tag = 1
        downloadedLanguagesTable.allowsMultipleSelection = true
        downloadedLanguagesTable.dataSource = self
        downloadedLanguagesTable.delegate = self
        downloadedLanguagesTable.register(UITableViewCell.self, forCellReuseIdentifier: "DownloadedLanguage")
        downloadedLanguagesTable.translatesAutoresizingMaskIntoConstraints = false
        downloadedLanguagesTable.heightAnchor.constraint(equalToConstant: 100).isActive = true
        
        return downloadedLanguagesTable
    }()
    
    private lazy var translatedPagesTotals: [(String, Int)] = {
        return fetchPageTranslationsTotals()
    }()
    
    private lazy var deleteTranslatedPagesButton: UIButton = {
        let button = UIButton(frame: .zero)
        let deleteImage = #imageLiteral(resourceName: "ic-actions-trash").withRenderingMode(.alwaysTemplate)
        button.setImage(deleteImage, for: .normal)
        button.isEnabled = false
        button.addTarget(self,
                         action: #selector(deleteTranslatedPagesButtonTapped),
                         for: .touchUpInside)
        return button
    }()
    
    private lazy var translatedPagesTable:UITableView = {
        let translatedPagesTable = UITableView(frame: .zero)
        translatedPagesTable.tag = 2
        translatedPagesTable.allowsMultipleSelection = true
        translatedPagesTable.dataSource = self
        translatedPagesTable.delegate = self
        translatedPagesTable.register(UITableViewCell.self, forCellReuseIdentifier: "TranslatedPage")
        translatedPagesTable.translatesAutoresizingMaskIntoConstraints = false
        translatedPagesTable.heightAnchor.constraint(equalToConstant: 100).isActive = true
        
        return translatedPagesTable
    }()
    
    private var translateCell = UITableViewCell()
    
    private let cellInset: CGFloat = 10
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        navigationItem.setRightBarButton(
            UIBarButtonItem(
                title: "Done",
                style: .done,
                target: self,
                action: #selector(doneTranslateButtonTapped)),
            animated: false)
        navigationController?.navigationBar.tintColor = .appMainColor
        
        title = "Book Translate Settings"
        
        
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
        
        configureTranslateCell()
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.downloadedLanguagesTable.reloadData()
        
        self.reloadTranslatedPageTotals()
        self.translatedPagesTable.reloadData()
        
    }
    
    func reloadTranslatedPageTotals() {
        self.translatedPagesTotals = fetchPageTranslationsTotals()
    }
    
    @objc private func doneTranslateButtonTapped() {
        do {
            let sourceLanguage = bookTranslateSourceOptions?[bookTranslateSourcePicker.selectedRow(inComponent: 0)] ?? "none"
            let targetLanguage = bookTranslateTargetOptions?[bookTranslateTargetPicker.selectedRow(inComponent: 0)] ?? "none"
            let translateMode =  TranslateMode.allCases[translateModeSegmentControl.selectedSegmentIndex]

            try dataService.saveTranslateSettingsOf(comic: self.comic!, sourcelanguage: sourceLanguage, targetlanguage: targetLanguage, translateMode: translateMode)
        } catch {
            showAlert(with: "Oh!", description: "There is a problem with saving your comic translate settings")
        }
        delegate?.doneTranslateButtonTapped()
    }
    
    private func configureTranslateCell() {
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
                
        let translateLanguagesStackView = UIStackView(frame: .zero)
        translateLanguagesStackView.axis = .horizontal
        translateLanguagesStackView.distribution = .fillEqually
        translateLanguagesStackView.translatesAutoresizingMaskIntoConstraints = false
        
        //SOURCE
        let sourceLanguageStackView = UIStackView()
        sourceLanguageStackView.axis = .horizontal
        sourceLanguageStackView.distribution = .fillProportionally
        sourceLanguageStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let sourceLanguageLabel = UILabel()
        sourceLanguageLabel.text = "Source:"
        sourceLanguageLabel.font = AppState.main.font.body
        sourceLanguageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        sourceLanguageStackView.addArrangedSubview(sourceLanguageLabel)
        sourceLanguageStackView.addArrangedSubview(bookTranslateSourcePicker)
        sourceLanguageStackView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        //TARGET
        let targetLanguageStackView = UIStackView()
        targetLanguageStackView.axis = .horizontal
        targetLanguageStackView.distribution = .fillProportionally
        targetLanguageStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let targetLanguageLabel = UILabel()
        targetLanguageLabel.text = "Target:"
        targetLanguageLabel.font = AppState.main.font.body
        targetLanguageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        targetLanguageStackView.addArrangedSubview(targetLanguageLabel)
        targetLanguageStackView.addArrangedSubview(bookTranslateTargetPicker)
        bookTranslateTargetPicker.heightAnchor.constraint(equalToConstant: 40).isActive = true
                
        translateLanguagesStackView.addArrangedSubview(sourceLanguageStackView)
        translateLanguagesStackView.addArrangedSubview(targetLanguageStackView)
        
        translateCell.contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leftAnchor.constraint(equalTo: translateCell.contentView.leftAnchor, constant: cellInset),
            stackView.rightAnchor.constraint(equalTo: translateCell.contentView.rightAnchor, constant: -cellInset),
            stackView.topAnchor.constraint(equalTo: translateCell.contentView.topAnchor, constant: cellInset),
            stackView.bottomAnchor.constraint(equalTo: translateCell.contentView.bottomAnchor, constant: -cellInset),
        ])
                
        stackView.addArrangedSubview(translateModeSegmentControl)
        stackView.addArrangedSubview(translateLanguagesStackView)
        
        var lastTranslateMode: Int
        if comic?.lastTranslateMode == 0 {
            lastTranslateMode = TranslateMode.onDevice.rawValue
        } else {
            lastTranslateMode = Int(comic?.lastTranslateMode ?? 1)
        }
        translateModeSegmentControl.selectedSegmentIndex = TranslateMode.allCases.firstIndex(of: TranslateMode(rawValue: lastTranslateMode)!)!
        
        let downloadedLanguagesStackView = UIStackView()
        downloadedLanguagesStackView.axis = .horizontal
        downloadedLanguagesStackView.distribution = .fillProportionally
        downloadedLanguagesStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let downloadedLanguagesLabel = UILabel()
        downloadedLanguagesLabel.text = "On Device Languages:"
        downloadedLanguagesLabel.font = AppState.main.font.body
        downloadedLanguagesLabel.translatesAutoresizingMaskIntoConstraints = false
        
        downloadedLanguagesStackView.addArrangedSubview(downloadedLanguagesLabel)
        downloadedLanguagesStackView.addArrangedSubview(deleteDownloadedLanguagesButton)
        
        stackView.addArrangedSubview(downloadedLanguagesStackView)
        stackView.addArrangedSubview(downloadedLanguagesTable)
        
        
        let translatedPagesStackView = UIStackView()
        translatedPagesStackView.axis = .horizontal
        translatedPagesStackView.distribution = .fillProportionally
        translatedPagesStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let translatedPagesLabel = UILabel()
        translatedPagesLabel.text = "Translated Pages Totals:"
        translatedPagesLabel.font = AppState.main.font.body
        translatedPagesLabel.translatesAutoresizingMaskIntoConstraints = false
        
        translatedPagesStackView.addArrangedSubview(translatedPagesLabel)
        translatedPagesStackView.addArrangedSubview(deleteTranslatedPagesButton)
        
        stackView.addArrangedSubview(translatedPagesStackView)
        stackView.addArrangedSubview(translatedPagesTable)
    }
    
    @objc
    func deleteTranslatedPagesButtonTapped() {
        do {
            print("deleteTranslatedPagesButtonTapped Tapped")
            guard let indexPathsForSelectedRows = translatedPagesTable.indexPathsForSelectedRows else { return }
            guard let comic = comic else { return }
            for indexPath in indexPathsForSelectedRows {
                let languageCode = translatedPagesTotals[indexPath.row].0
                try dataService.deletePageTranslationsFromCoreData(comic: comic, with: languageCode)
                
                self.reloadTranslatedPageTotals()
                self.translatedPagesTable.reloadData()
                self.deleteTranslatedPagesButton.isEnabled = false
            }
        } catch {
            showAlert(with: "Oh!", description: "There is a problem with deleting your comic translated pages")
        }
    }
    
    @objc
    func deleteDownloadedLanguagesButtonTapped() {
        print("deleteDownloadedLanguagesButton pressed")
        guard let indexPathsForSelectedRows = downloadedLanguagesTable.indexPathsForSelectedRows else { return }
        for indexPath in indexPathsForSelectedRows {
            
            let language = ModelManager.modelManager()
                .downloadedTranslateModels
                .map { $0.language }[indexPath.row]
            
            let model = TranslateRemoteModel.translateRemoteModel(language: language)
            let modelManager = ModelManager.modelManager()
            let languageName = Locale.current.localizedString(forLanguageCode: language.rawValue)!
            weak var weakSelf = self
            if modelManager.isModelDownloaded(model) {
                guard let strongSelf = weakSelf else {
                  print("Self is nil!")
                  return
                }
                print("Deleting \(languageName)")
                modelManager.deleteDownloadedModel(model) { error in
                    print("Deleted \(languageName) \(error.debugDescription)")
                    strongSelf.downloadedLanguagesTable.reloadData()
                    strongSelf.deleteDownloadedLanguagesButton.isEnabled = false
                }
            }
        }
    }
    
    func fetchPageTranslationsTotals() -> [(String, Int)] {
        var result:[(String, Int)] = []
        do {
            result = try dataService.fetchPageTranslationsTotalsOf(comic: comic)
        } catch {
            showAlert(with: "Oh!", description: "There is a problem with loading your comic translated pages totals")
        }
        return result
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count = 0
        switch tableView.tag
        {
        case 0:
            count = 1
        case 1:
            count = ModelManager.modelManager().downloadedTranslateModels.count
        case 2:
            count = translatedPagesTotals.count
        default:
            count = 0
        }
        return count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        switch tableView.tag
        {
        case 0:
            if indexPath.row == 0 {
                cell = translateCell
            } else {
                fatalError()
            }
        case 1:
            cell = tableView.dequeueReusableCell(withIdentifier: "DownloadedLanguage")! as UITableViewCell
            cell.textLabel?.text = ModelManager.modelManager()
                .downloadedTranslateModels
                .map { model in
                    let languageCode = model.language.rawValue
                    var language = Locale.current.localizedString(forLanguageCode:languageCode)!
                    if model.language == .english {
                        language += " (Permanent)"
                    }
                    return language
                }[indexPath.row]
            let selectedIndexPaths = tableView.indexPathsForSelectedRows
            let rowIsSelected = selectedIndexPaths != nil && selectedIndexPaths!.contains(indexPath)
            cell.accessoryType = rowIsSelected ? .checkmark : .none
        case 2:
            let languageCode = translatedPagesTotals[indexPath.row].0
            let language = Locale.current.localizedString(forLanguageCode: languageCode)!
            let pageTotals = translatedPagesTotals[indexPath.row].1
            
            cell = tableView.dequeueReusableCell(withIdentifier: "TranslatedPage")! as UITableViewCell
            cell.textLabel?.text = "\(language): \(pageTotals)"
            
            let selectedIndexPaths = tableView.indexPathsForSelectedRows
            let rowIsSelected = selectedIndexPaths != nil && selectedIndexPaths!.contains(indexPath)
            cell.accessoryType = rowIsSelected ? .checkmark : .none
        default:
            fatalError()
        }
       
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.tag == 1 {
            guard let cell = tableView.cellForRow(at: indexPath) else { return }
            
            let language = ModelManager.modelManager()
                .downloadedTranslateModels
                .map { $0.language }[indexPath.row]
            if language == .english { //english will not be deleted by mlkit, idk
                tableView.deselectRow(at: indexPath, animated: false)
                return
            }
            
            cell.accessoryType = .checkmark
            deleteDownloadedLanguagesButton.isEnabled = true
        } else if tableView.tag == 2 {
            guard let cell = tableView.cellForRow(at: indexPath) else { return }
            
            cell.accessoryType = .checkmark
            deleteTranslatedPagesButton.isEnabled = true
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.tag == 1 {
            guard let cell = tableView.cellForRow(at: indexPath) else { return }
            cell.accessoryType = .none
            if tableView.indexPathsForSelectedRows == nil {
                deleteDownloadedLanguagesButton.isEnabled = false
            } else if tableView.indexPathsForSelectedRows?.count == 1  {
                tableView.indexPathsForSelectedRows?.forEach { indexPath in
                    let language = ModelManager.modelManager()
                        .downloadedTranslateModels
                        .map { $0.language }[indexPath.row]
                    if language == .english { //english will not be deleted by mlkit, idk
                        deleteDownloadedLanguagesButton.isEnabled = false
                    }
                }
            }
        } else if tableView.tag == 2 {
            guard let cell = tableView.cellForRow(at: indexPath) else { return }
            cell.accessoryType = .none
            if tableView.indexPathsForSelectedRows == nil {
                deleteTranslatedPagesButton.isEnabled = false
            }
        }
    }
}

