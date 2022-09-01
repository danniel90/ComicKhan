//
//  ReaderTranslate.swift
//  wutComicReader
//
//  Created by Daniel on 8/30/22.
//

import Foundation

enum TranslateMode: Int, CaseIterable {
    case onDevice = 1
    case online = 2
    
    var name: String {
        switch self {
        case .onDevice:
            return "On Device (Low Quality)"
        case .online:
            return "Online (Mid Quality)"
        }
    }
}
