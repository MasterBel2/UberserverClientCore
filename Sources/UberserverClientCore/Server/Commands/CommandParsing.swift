//
//  CommandParsing.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 29/8/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation

/// Indicates an error that occured in the process of decoding server commands
enum ParsingError: Error {
	case noCharactersRemaining
    case tooFewWords
    case tooFewSentences
}

// WIP

func wordsAndSentences(for commandPayload: String, wordCount: Int, sentenceCount: Int) throws -> (words: [String], sentences: [String]) {

    let (words, sentences, _, _) = try wordsAndSentences(for: commandPayload, wordCount: wordCount, sentenceCount: sentenceCount, optionalWordCount: 0, optionalSentenceCount: 0)
    return (words, sentences)
}

/// Breaks a server command into its component words and sentences, as indicated by the lobby protocol.
///
/// See https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html for more detail.
func wordsAndSentences(for commandPayload: String, wordCount: Int, sentenceCount: Int, optionalWordCount: Int = 0, optionalSentenceCount: Int = 0) throws -> (words: [String], sentences: [String], optionalWords: [String], optionalSentences: [String]) {
	var remainingCharacters = commandPayload
	var buffer = [Character]()
	var words = [String]()
	var sentences = [String]()
    var optionalWords = [String]()
    var optionalSentences = [String]()

    func x(array: inout Array<String>, count: Int, separator: Character) {
        while array.count < count {
            guard let character = remainingCharacters.first else {
                array.append(String(buffer))
                return
            }
            if character == separator {
                array.append(String(buffer))
                buffer = []
            } else {
                buffer.append(character)
            }

            remainingCharacters = String(remainingCharacters.dropFirst())
        }
    }

    x(array: &words, count: wordCount, separator: " ")
    guard words.count == wordCount else {
        throw ParsingError.tooFewWords
    }

	// Sentences are separated by a tab character. There is no tab character before the first sentence

    x(array: &sentences, count: sentenceCount, separator: "\t")
    guard sentences.count == sentenceCount else {
        throw ParsingError.tooFewSentences
    }

    x(array: &optionalWords, count: optionalWordCount, separator: " ")
    x(array: &optionalSentences, count: optionalSentenceCount, separator: "\t")
    #warning("This will likely not correctly decode multiple optionals: maybe use \"separators\" rather than \"separator\"?")

	if remainingCharacters != "" {
		print("Command payload incorrectly parsed: remaning text was \"\(remainingCharacters)\"")
	}
    return (words: words, sentences: sentences, optionalWords: optionalWords, optionalSentences: optionalSentences)
}
