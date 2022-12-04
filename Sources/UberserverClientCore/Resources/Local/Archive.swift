//
//  Archive.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 30/7/20.
//  Copyright © 2020 MasterBel2. All rights reserved.
//

import Foundation

// MARK: - Archives

public protocol Archive {
	var checksum: Int32 { get }
	var archiveName: String { get }
	var name: String { get }
	var path: String { get }
	var singleArchiveChecksum: Int32 { get }
	
	var info: [ArchiveInfo] { get }
	var dependencies: [UnitsyncArchive] { get }
	var options: [ArchiveOption] { get }
}

public struct ArchiveInfo {
	public let key: String
	public let description: String
	public let value: Value
	public enum Value: CustomStringConvertible {
		case string(String)
		case integer(Int)
		case float(Float)
		case boolean(Bool)
		
		public var description: String {
			switch self {
			case .string(let string):
				return string
			case .integer(let int):
				return String(int)
			case .float(let float):
				return String(float)
			case .boolean(let bool):
				return bool ? "1" : "0"
			}
		}
	}
	public var fullDescription: String {
		return "\(key) = \(value.description) ; \(description)"
	}
}

public struct ArchiveOption {
	public let key: String
	public let name: String
	public let description: String
	public let type: ValueType?
	public let section: String

	public enum ValueType: CInt {
		case dunno = 1
	}
}

// MARK: - Mods

public protocol ModArchive: Archive {
	var completeChecksum: Int32 { get }
	var factions: [Faction] { get }
}

public struct Faction {
	public let name: String
	public let startUnit: String
}

// MARK: - Maps

public protocol MapArchive: Archive {
	
	var heightRange: ClosedRange<Float> { get }
	
	var width: Int { get }
	var height: Int { get }
	var grassMap: InfoMap<UInt8> { get }
	var heightMap: InfoMap<UInt16> { get }
	var metalMap: InfoMap<UInt8> { get }
	var typeMap: InfoMap<UInt8> { get }
	var fileName: String { get }
	var completeChecksum: Int32 { get }
}

public final class InfoMap<PixelType: UnsignedInteger> {
	public enum Name: String {
		case grass
		case height
		case metal
		case type
	}
	
	let loadSize: (_ name: Name) -> (width: Int, height: Int)
	let loadPixels: (_ name: Name, _ loadInto: UnsafeMutablePointer<UInt8>) -> ()

	public init(name: Name, loadSize: @escaping (_ name: Name) -> (width: Int, height: Int), loadPixels: @escaping (_ name: Name, _ loadInto: UnsafeMutablePointer<UInt8>) -> () ) {
		self.name = name
		self.loadSize = loadSize
		self.loadPixels = loadPixels
	}

	public let name: Name
	public private(set) lazy var size: (width: Int, height: Int) = loadSize(name)
	
	public private(set) lazy var pixels: [PixelType] = {
		var pixels: [PixelType] = Array<PixelType>(repeating: PixelType(), count: size.width * size.height)
		withUnsafePointer(to: &pixels) { pixelPointer in
			pixelPointer.withMemoryRebound(to: UInt8.self, capacity: 1) { bytePointer in
				loadPixels(name, UnsafeMutablePointer(mutating: bytePointer))
			}
		}
		return pixels
	}()
}

// MARK: - Skirmish AIs

public protocol SkirmishAIArchive: Archive {}
