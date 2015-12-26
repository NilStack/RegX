//
//  Regularize.swift
//  RegX
//
//  Created by Krunoslav Zaher on 10/15/14.
//  Copyright (c) 2014 Krunoslav Zaher. All rights reserved.
//

import Foundation

public class Regularizer  {
    let tabWidth : Int
    
    init (tabWidth : Int) {
        self.tabWidth = tabWidth
    }
    
    private enum ParsedLineResult {
        case Raw(String)
        case Sections([String])
        
        func description() -> String {
            switch (self) {
            case .Raw(let line):return line
            case .Sections(let columns):return columns.joinWithSeparator("|")
            }
        }
        
        var numberOfColumns : Int {
            switch (self) {
            case .Raw:
                assert(false)
                return 0
            case .Sections(let columns):
                return columns.count
            }
        }
    }
    
    private class func maxColumnWidth(parsedLines : [ParsedLineResult], index: Int) -> Int {
        return parsedLines.reduce(0) { max, line -> Int in
            switch line {
            case .Raw(_):
                return max
            case .Sections(let columns):
                if columns.count > index {
                    let column = columns[index]
                    let length = column.count()
                    return length > max ? length : max
                }
                else {
                    return max
                }
            }
        }
    }
    
    private class func paddColumnToWidths(parsedLines : [ParsedLineResult], widths: [Int]) -> [ParsedLineResult] {
        return parsedLines.map { line in
            switch (line) {
            case .Sections(let columns):
                let transformed = zip(columns, widths).map {
                    $0.stringByPaddingToLength($1, withString: " ", startingAtIndex: 0)
                }
                return .Sections(transformed)
            default:
                return line
            }
        }
    }

    private class func isWhitespace(char: Character) -> Bool {
        // other solutions is swift were too compicated
        // this was good enough
        return char == " " || char == "\n" || char == "\t"
    }
    
    private class func trimStartWhitespace(string: String) -> String {
        var i = string.startIndex
        for i = string.startIndex; i < string.endIndex && i < string.endIndex.predecessor(); i = i.successor() {
            let char = string[i]
            if !Regularizer.isWhitespace(char) {
                break;
            }
        }
        
        return string.substringWithRange(Range<String.Index>(start: i, end: string.endIndex))
    }
    
    private class func trimEndWhitespace(string: String) -> String {
        var i = string.endIndex
        for i = string.endIndex; i > string.startIndex; i = i.predecessor() {
            let previousIndex = i.predecessor()
            let previousCharacter = string[previousIndex]
            if !Regularizer.isWhitespace(previousCharacter) {
                break;
            }
        }
        
        return string.substringWithRange(Range<String.Index>(start: string.startIndex, end: i))
    }
    
    private class func trim(string: String, start: Bool, end: Bool) -> String {
        let str1 = start ? Regularizer.trimStartWhitespace(string) : string
        let str2 = end ? Regularizer.trimEndWhitespace(str1) : str1
        
        return str2
    }
    
    private func finalColumnWidth(startWidth: Int) -> Int {
        let minimalTargetWidth = startWidth
        
        let tabWidth = self.tabWidth > 0 ? self.tabWidth: 4
        
        return minimalTargetWidth % tabWidth == 0
                ? minimalTargetWidth
                : ((minimalTargetWidth / tabWidth) + 1) * tabWidth
    }
    
    func regularize(text: String,
                settings:[GroupSettings],
        regularExpression: NSRegularExpression) -> String {
        let lines = text.componentsSeparatedByString("\n")
        
        let parsedLines : [ParsedLineResult] = lines.map { line -> ParsedLineResult in
            if (line.count() == 0) {
                return ParsedLineResult.Raw(line)
            }
            
            let range = NSMakeRange(0, line.count())
            let matches = regularExpression.matchesInString(line, options:NSMatchingOptions(), range:range)
            
            if (matches.count == 0) {
                return ParsedLineResult.Raw(line)
            }
            
            let match : NSTextCheckingResult = matches[0]
            var tokens : [String] = []
            
            var widthGroup = 0
            for i in 1..<match.numberOfRanges {
                let range : NSRange = match.rangeAtIndex(i)
                if range.location == NSNotFound {
                    continue
                }
                let substring = (line as NSString).substringWithRange(range)
                
                let settings = settings[i - 1]

                let paddingBefore = settings.paddingBefore != nil ? settings.paddingBefore! : 0
                let paddingBeforeString = "".stringByPaddingToLength(paddingBefore, withString: " ", startingAtIndex: 0)
                
                let paddingAfter = settings.paddingAfter != nil ? settings.paddingAfter! : 0
                let paddingAfterString  = "".stringByPaddingToLength(paddingAfter, withString: " ", startingAtIndex: 0)
                
                let trimmedString = Regularizer.trim(substring, start: settings.paddingBefore != nil, end: settings.paddingAfter != nil)
                
                tokens.append(paddingBeforeString + trimmedString + paddingAfterString)

                widthGroup++
            }

            return ParsedLineResult.Sections(tokens)
        }
        
        let maxNumColumns = parsedLines.reduce(0) {
            switch ($1) {
            case .Sections(let sections):
                return $0 > sections.count ? $0 : sections.count
            default:
                return $0
            }
        }
        
        var resultColumns = parsedLines
        let widths = sequence(0..<maxNumColumns).map {
            self.finalColumnWidth(Regularizer.maxColumnWidth(parsedLines, index: $0))
        }
        
        resultColumns = Regularizer.paddColumnToWidths(resultColumns, widths: widths)
        
        let linesWithJoinedLineContent = resultColumns.map { line -> String in
            switch (line) {
            case .Sections(let columns):
                return Regularizer.trimEndWhitespace(columns.joinWithSeparator(""))
            case .Raw(let content):
                return content
            }
        }
      
        return linesWithJoinedLineContent.joinWithSeparator("\n")
    }
}
