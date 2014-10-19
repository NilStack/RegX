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
            case .Sections(let columns):return "|".join(columns)
            }
        }
        
        var numberOfColumns : Int {
            switch (self) {
            case .Raw(let line):
                assert(false)
                return 0
            case .Sections(let columns):
                return columns.count
            }
        }
    }
    
    private class func maxColumnWidth(parsedLines : [ParsedLineResult], index: Int) -> Int {
        return reduce(parsedLines, 0, { max, line -> Int in
            switch line {
            case .Raw(_):
                return max
            case .Sections(let columns):
                if columns.count > index {
                    let column = columns[index]
                    let length = countElements(column)
                    return length > max ? length : max
                }
                else {
                    return max
                }
            }
        })
    }
    
    private class func paddColumnToWidths(parsedLines : [ParsedLineResult], widths: [Int]) -> [ParsedLineResult] {
        return map(parsedLines) { line in
            switch (line) {
            case .Sections(let columns):
                let transformed = map(zip(columns, widths)) {
                    $0.stringByPaddingToLength($1, withString: " ", startingAtIndex: 0)
                }
                return .Sections(transformed)
            default:
                return line
            }
        }
    }
    
    private class func trimEndWhitespace(string: String) -> String {
        var i = string.endIndex
        for i = string.endIndex; i > string.startIndex; i = i.predecessor() {
            let previousIndex = i.predecessor()
            let previousCharacter = string[previousIndex]
            // other solutions is swift were too compicated
            // this was good enough
            if !(previousCharacter == " " || previousCharacter == "\n" || previousCharacter == "\t") {
                break;
            }
        }
        
        return string.substringWithRange(Range<String.Index>(start: string.startIndex, end: i))
    }
    
    private func finalColmnWidth(startWidth: Int) -> Int {
        let minimalTargetWidth = startWidth
        
        let tabWidth = self.tabWidth > 0 ? self.tabWidth: 4
        
        return minimalTargetWidth % tabWidth == 0
                ? minimalTargetWidth
                : ((minimalTargetWidth / tabWidth) + 1) * tabWidth
    }
    
    public func regularize(text: String, minSpaces: [Int], regularExpression: NSRegularExpression) -> String {
        let lines = text.componentsSeparatedByString("\n")
        
        let parsedLines : [ParsedLineResult] = lines.map { line -> ParsedLineResult in
            if (countElements(line) == 0) {
                return ParsedLineResult.Raw(line)
            }
            
            let range = NSMakeRange(0, countElements(line))
            let matches = regularExpression.matchesInString(line, options:NSMatchingOptions.allZeros, range:range)
            
            if (matches.count == 0) {
                return ParsedLineResult.Raw(line)
            }
            
            let match : NSTextCheckingResult = matches[0] as NSTextCheckingResult
            var tokens : [String] = []
            
            var widthGroup = 0
            for i in 1..<match.numberOfRanges {
                let range : NSRange = match.rangeAtIndex(i)
                if range.location == NSNotFound {
                    continue
                }
                let substring = (line as NSString).substringWithRange(range)
                let rightPadding = "".stringByPaddingToLength(minSpaces[widthGroup], withString: " ", startingAtIndex: 0)
                tokens.append(Regularizer.trimEndWhitespace(substring) + rightPadding)

                widthGroup++
            }

            return ParsedLineResult.Sections(tokens)
        }
        
        var maxNumColumns = reduce(parsedLines, 0) {
            switch ($1) {
            case .Sections(let sections):
                return $0 > sections.count ? $0 : sections.count
            default:
                return $0
            }
        }
        
        var resultColumns = parsedLines
        var widths = map(sequence(0..<maxNumColumns)) {
            self.finalColmnWidth(Regularizer.maxColumnWidth(parsedLines, index: $0))
        }
        
        resultColumns = Regularizer.paddColumnToWidths(resultColumns, widths: widths)
        
        let linesWithJoinedLineContent = resultColumns.map { line -> String in
            switch (line) {
            case .Sections(let columns):
                return Regularizer.trimEndWhitespace("".join(columns))
            case .Raw(let content):
                return content
            }
        }
      
        return "\n".join(linesWithJoinedLineContent)
    }
}