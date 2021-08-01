//
//  Socket.swift
//  OSXSpringLobby
//
//  Created by Belmakor on 30/06/2016.
//  Copyright © 2016 MasterBel2. All rights reserved.
//

import Foundation
import ServerAddress

private enum SocketError: Error {
    case failedToSetStreamProperty(property: Any?, key: Stream.PropertyKey)
}

/// A set of functions that may be implemented by a Socket's delegate.
protocol SocketDelegate: AnyObject {
	func socket(_ socket: Socket, didReceive message: String)
    func socket(_ socket: Socket, didFailWithError error: Error?)
}

/// Creates a socket connection to a host.
final class Socket: NSObject, StreamDelegate {
	
	// MARK: - Properties

    /// The socket's delegate
	weak var delegate: SocketDelegate?

    /// The address the socket connected to.
	let address: ServerAddress
    
	private let inputStream: InputStream
	private let outputStream: OutputStream

	private let messageBuffer = NSMutableData(capacity: 256)!

    /// Whether the socket is currently open.
	public private(set) var isOpen: Bool = false
	
	// MARK: - Lifecycle
	
	init?(address: ServerAddress) {
        var inputStream: InputStream?
        var outputStream: OutputStream?

        Stream.getStreamsToHost(withName: address.location, port: address.port, inputStream: &inputStream, outputStream: &outputStream)

        if let inputStream = inputStream,
           let outputStream = outputStream {

            self.address = address

            self.inputStream = inputStream
            self.outputStream = outputStream

            super.init()

            inputStream.delegate = self
            outputStream.delegate = self

            inputStream.schedule(in: .current, forMode: .default)
            outputStream.schedule(in: .current, forMode: .default)
        } else {
            print("Failed to get input & output streams")
            return nil
        }
	}

    /// Opens the socket.
    ///
    /// Note the socket cannot be re-opened after it is closed.
    func open() {
        guard !isOpen else { return }

        inputStream.open()
        outputStream.open()

        isOpen = true
    }

    func setStreamProperty(_ property: Any?, forKey key: Stream.PropertyKey) throws {
        guard inputStream.setProperty(property, forKey: key),
              outputStream.setProperty(property, forKey: key) else {
            inputStream.setProperty(nil, forKey: key)
            outputStream.setProperty(nil, forKey: key)
            throw SocketError.failedToSetStreamProperty(property: property, key: key)
        }
    }

    /// Closes the socket.
    ///
    /// Note that the socket cannot be re-opened after it is closed.
    func close() {
        guard isOpen else { return }

        inputStream.close()
        outputStream.close()

        isOpen = false
    }

    /// Writes the string to the Socket's output stream, encoded with UTF8.
	func send(message: String) {
		guard let data = message.data(using: String.Encoding.utf8, allowLossyConversion: false) else {
			print("Cannot convert message into data to send: invalid format?")
			return
		}
		
		var bytes = Array<UInt8>(repeating: 0, count: data.count)
		(data as NSData).getBytes(&bytes, length: data.count)
		outputStream.write(&bytes, maxLength: data.count)
	}
	
	// MARK: - StreamDelegate
	
	func stream(_ stream: Stream, handle eventCode: Stream.Event) {
		switch eventCode {
			
		case Stream.Event():
			break
			
		case Stream.Event.openCompleted:
			break
			
		case Stream.Event.hasBytesAvailable:
			guard let input = stream as? InputStream else { break }
			
			var byte: UInt8 = 0
			while input.hasBytesAvailable {
				let bytesRead = input.read(&byte, maxLength: 1)
				messageBuffer.append(&byte, length: bytesRead)
			}
			// only inform our delegate of complete messages (must end in newline character)
			if let message = String(data: messageBuffer as Data, encoding: String.Encoding.utf8), message.hasSuffix("\n") {
				delegate?.socket(self, didReceive: message)
				messageBuffer.length = 0
			}
			
		case Stream.Event.hasSpaceAvailable:
			break
			
        case Stream.Event.errorOccurred:
            delegate?.socket(self, didFailWithError: stream.streamError)
            close()
        case Stream.Event.endEncountered:
			close()
		default:
			print(eventCode)
		}
	}
}
