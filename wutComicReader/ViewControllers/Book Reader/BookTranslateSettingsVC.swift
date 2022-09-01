//
//  BookTranslateSettingsVC.swift
//  wutComicReader
//
//  Created by Daniel on 8/31/22.
//

import Foundation
import UIKit


class BookTranslateSettingsVC: UINavigationController {
    init(settingDelegate: BookTranslateSettingsVCDelegate? = nil) {
        let vc = SettingVC()
        vc.delegate = settingDelegate
        super.init(rootViewController: vc)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

protocol BookTranslateSettingsVCDelegate: AnyObject {
    func doneTranslateButtonTapped()
}

fileprivate final class SettingVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    weak var delegate: BookTranslateSettingsVCDelegate?
    
    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .insetGrouped)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var readerTranslateSourcePicker: UIPickerView = {
        let inputPickerView = UIPickerView(frame: .zero)
        inputPickerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        inputPickerView.tag = 0
        inputPickerView.translatesAutoresizingMaskIntoConstraints = false
        
        return inputPickerView
    }()
    
    private lazy var readerTranslateTargetPicker: UIPickerView = {
        let outputPickerView = UIPickerView(frame: .zero)
        outputPickerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        outputPickerView.tag = 1
        outputPickerView.translatesAutoresizingMaskIntoConstraints = false
        
        return outputPickerView
    }()
    
    private lazy var translateModeSegmentControl: UISegmentedControl = {
        let view = UISegmentedControl(frame: .zero, actions: TranslateMode.allCases.map({ translateMode in
            return UIAction(title: translateMode.name, handler: { [weak self] _ in
                self?.translateModeChanged(to: translateMode)
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
        sourceLanguageStackView.addArrangedSubview(readerTranslateSourcePicker)
        sourceLanguageStackView.heightAnchor.constraint(equalToConstant: 30).isActive = true
        
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
        targetLanguageStackView.addArrangedSubview(readerTranslateTargetPicker)
        readerTranslateTargetPicker.heightAnchor.constraint(equalToConstant: 30).isActive = true
                
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
    }
    
    private func translateModeChanged(to translateMode: TranslateMode) {
        
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

