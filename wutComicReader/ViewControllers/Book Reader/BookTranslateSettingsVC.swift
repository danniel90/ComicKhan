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
    
    init(settingDelegate: BookTranslateSettingsVCDelegate? = nil, comic: Comic?) {
        let vc = SettingVC()
        vc.delegate = settingDelegate
        vc.comic = comic
        super.init(rootViewController: vc)
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
            count = bookTranslateSourceOptions.count
        case 1:
            count = bookTranslateTargetOptions.count
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
            let selectedOption = bookTranslateSourceOptions[row]
            if selectedOption == "none" || selectedOption == "detect" {
                pickedString = selectedOption
            } else {
                let language = locale.localizedString(forLanguageCode: selectedOption) ?? ""
                pickedString = "\(language) (\(selectedOption))"
            }
            
        case 1:
            let selectedOption = bookTranslateTargetOptions[row]
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
            message += bookTranslateSourceOptions[pickerView.selectedRow(inComponent: 0)]
        case 1:
            message += bookTranslateTargetOptions[pickerView.selectedRow(inComponent: 0)]
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
    var comic : Comic? 
    private(set) var dataService: DataService = Cores.main.dataService
    let locale = Locale.current
    lazy var bookTranslateSourceOptions: [String] = {
        var options = allLanguages.map {
            $0.rawValue
        }
        options.insert(contentsOf: ["none", "detect"], at: 0)
        return options
    }()
    
    lazy var bookTranslateTargetOptions: [String] = {
        var options = allLanguages.map {
            $0.rawValue
        }
        options.insert("none", at: 0)
        return options
    }()
    
    lazy var allLanguages = TranslateLanguage.allLanguages().sorted {
        return locale.localizedString(forLanguageCode: $0.rawValue)!
        < locale.localizedString(forLanguageCode: $1.rawValue)!
    }
    
    weak var delegate: BookTranslateSettingsVCDelegate?
    
    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .insetGrouped)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var bookTranslateSourcePicker: UIPickerView = {
        let inputPickerView = UIPickerView(frame: .zero)
        inputPickerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        inputPickerView.tag = 0
        inputPickerView.dataSource = self
        inputPickerView.selectRow(bookTranslateSourceOptions.firstIndex(of: comic?.inputLanguage ?? "none") ?? 0, inComponent: 0, animated: false)
        inputPickerView.delegate = self
        inputPickerView.translatesAutoresizingMaskIntoConstraints = false
        
        return inputPickerView
    }()
    
    private lazy var bookTranslateTargetPicker: UIPickerView = {
        let outputPickerView = UIPickerView(frame: .zero)
        outputPickerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        outputPickerView.tag = 1
        outputPickerView.dataSource = self
        outputPickerView.selectRow(bookTranslateTargetOptions.firstIndex(of: comic?.lastOutputLanguage ?? "none") ?? 0, inComponent: 0, animated: false)
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
    
    @objc private func doneTranslateButtonTapped() {
        do {
            let sourceLanguage = bookTranslateSourceOptions[bookTranslateSourcePicker.selectedRow(inComponent: 0)]
            let targetLanguage = bookTranslateTargetOptions[bookTranslateTargetPicker.selectedRow(inComponent: 0)]
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
        
        stackView.addArrangedSubview(translateLanguagesStackView)
        stackView.addArrangedSubview(translateModeSegmentControl)
        
        var lastTranslateMode: Int
        if comic?.lastTranslateMode == 0 {
            lastTranslateMode = TranslateMode.onDevice.rawValue
        } else {
            lastTranslateMode = Int(comic?.lastTranslateMode ?? 1)
        }
        translateModeSegmentControl.selectedSegmentIndex = TranslateMode.allCases.firstIndex(of: TranslateMode(rawValue: lastTranslateMode)!)!
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            return translateCell
        }
        
        fatalError()
        
        
    }
}

