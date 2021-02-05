//
//  UnitsyncArchive.swift
//  
//
//  Created by MasterBel2 on 3/2/21.
//

import Foundation

// MARK: - Maps

final class UnitsyncMapArchive: UnitsyncArchive, MapArchive {

	// MARK: Properties

	private(set) lazy var heightRange: ClosedRange<Float> = { unitsyncWrapper.GetMapMinHeight(name.utf8CStringArray)...unitsyncWrapper.GetMapMaxHeight(name.utf8CStringArray) }()

	private(set) lazy var width: Int = { Int(unitsyncWrapper.GetMapWidth(archiveIndex)) }()
	private(set) lazy var height: Int = { Int(unitsyncWrapper.GetMapHeight(archiveIndex)) }()
	private(set) lazy var grassMap: InfoMap = { InfoMap<UInt8>(name: .grass, loadSize: loadInfoMapSize(infoMapName:), loadPixels: loadInfoMapPixels(infoMapName:loadDestination:)) }()
	private(set) lazy var heightMap: InfoMap = { InfoMap<UInt16>(name: .height, loadSize: loadInfoMapSize(infoMapName:), loadPixels: loadInfoMapPixels(infoMapName:loadDestination:)) }()
	private(set) lazy var metalMap: InfoMap = { InfoMap<UInt8>(name: .metal, loadSize: loadInfoMapSize(infoMapName:), loadPixels: loadInfoMapPixels(infoMapName:loadDestination:)) }()
	private(set) lazy var typeMap: InfoMap = { InfoMap<UInt8>(name: .type, loadSize: loadInfoMapSize(infoMapName:), loadPixels: loadInfoMapPixels(infoMapName:loadDestination:)) }()
	private(set) lazy var miniMap: Minimap = { Minimap(loadPixels: loadMinimapPixels(mipLevel:count:)) }()
	private(set) lazy var fileName: String = { String(cString: unitsyncWrapper.GetMapFileName(archiveIndex) )}()
	private(set) lazy var completeChecksum: UInt32 = { unitsyncWrapper.GetMapChecksum(archiveIndex) }()

	// MARK: Overrides

	override var checksum: UInt32 {
		return completeChecksum
	}

	override var optionCount: CInt {
		return unitsyncWrapper.GetMapOptionCount(name.utf8CStringArray)
	}
	override func archiveDependencyName(at index: CInt) -> String {
		String(cString: unitsyncWrapper.GetMapArchiveName(index))
	}
	override var archiveDependencyCount: CInt {
		return unitsyncWrapper.GetMapArchiveCount(name.utf8CStringArray)
	}
	override var infoCount: CInt {
		unitsyncWrapper.GetMapInfoCount(archiveIndex)
	}
	
	// MARK: Unitsync
	
	func loadInfoMapSize<T>(infoMapName: InfoMap<T>.Name) -> (width: Int, height: Int) {
		let cName = infoMapName.rawValue.cString(using: .utf8)!
		var height = CInt()
		var width = CInt()
		withUnsafePointer(to: cName[0]) { cNamePointer in
			_ = unitsyncWrapper.GetInfoMapSize(name, cNamePointer, &width, &height)
		}
		return (width: Int(width), height: Int(height))
	}
	
	func loadInfoMapPixels<T>(infoMapName: InfoMap<T>.Name, loadDestination: UnsafeMutablePointer<UInt8>) {
		let cName = infoMapName.rawValue.cString(using: .utf8)!
		withUnsafePointer(to: cName[0]) { cName in
			_ = unitsyncWrapper.GetInfoMap(name, cName, loadDestination, CInt(MemoryLayout<T>.size))
		}
	}
	
	func loadMinimapPixels(mipLevel: Int, count: Int) -> [RGB565Color] {
		let minimapPointer = unitsyncWrapper.GetMinimap(name, CInt(mipLevel))
		return Array(UnsafeBufferPointer(start: minimapPointer, count: count))
	}
}

// MARK: - Mods

final class UnitsyncModArchive: UnitsyncArchive, ModArchive {
	
	// MARK: Properties

	private(set) lazy var completeChecksum: UInt32 = { unitsyncWrapper.GetPrimaryModChecksum(archiveIndex) }()

	private(set) lazy var factions: [Faction] = {
		return executeOnVFS {
			return (0..<unitsyncWrapper.GetSideCount()).map({ index in
				return Faction(
					name: String(cString: unitsyncWrapper.GetSideName(index)),
					startUnit: String(cString: unitsyncWrapper.GetSideStartUnit(index))
				)
			})
		}
	}()
	
	// MARK: Overrides

	override var archiveName: String {
		switch info.first(where: { $0.key == "name" })?.value {
		case .string(let string):
			return string
		default:
			fatalError()
		}
	}

	override func archiveDependencyName(at index: CInt) -> String {
		return String(cString: unitsyncWrapper.GetPrimaryModArchiveList(index))
	}

	override var archiveDependencyCount: CInt {
		return unitsyncWrapper.GetPrimaryModArchiveCount(archiveIndex)
	}

	override var infoCount: CInt {
		return unitsyncWrapper.GetPrimaryModInfoCount(archiveIndex)
	}

	override var optionCount: CInt {
		return executeOnVFS {
			return unitsyncWrapper.GetModOptionCount()
		}
	}
}

// MARK: - Skirmish AIs

final class UnitsyncSkirmishAIArchive: UnitsyncArchive, SkirmishAIArchive {
	override var archiveDependencyCount: CInt {
		return 0
	}

	override var infoCount: CInt {
		return unitsyncWrapper.GetSkirmishAIInfoCount(archiveIndex)
	}

	override var optionCount: CInt {
		return unitsyncWrapper.GetSkirmishAIOptionCount(archiveIndex)
	}

	override var archiveName: String {
		switch info.first(where: { $0.key == "name" })?.value {
		case .string(let string):
			return string
		default:
			fatalError()
		}
	}
}

// MARK: - Generic Archive

public class UnitsyncArchive: Archive {
	init(archiveIndex: CInt, archiveName: String, unitsyncWrapper: UnitsyncWrapper) {
		self.unitsyncWrapper = unitsyncWrapper
		self.archiveIndex = archiveIndex
		self.name = archiveName
	}
	init(archiveIndex: CInt, unitsyncWrapper: UnitsyncWrapper) {
		self.unitsyncWrapper = unitsyncWrapper
		self.archiveIndex = archiveIndex
	}

	let unitsyncWrapper: UnitsyncWrapper

	let archiveIndex: CInt
	public private(set) lazy var name: String = archiveName
	public private(set) lazy var path: String = { String(cString: unitsyncWrapper.GetArchivePath(name.utf8CStringArray)) }()
	public private(set) lazy var singleArchiveChecksum: UInt32 = { unitsyncWrapper.GetArchiveChecksum(name.utf8CStringArray) }()

	public var checksum: UInt32 { return singleArchiveChecksum }

	public private(set) lazy var info = loadInfo()
	public private(set) lazy var dependencies = loadDependencies()
	public private(set) lazy var options = loadOptions()

	// MARK: - Loading data

	private func loadInfo() -> [ArchiveInfo] {
		return (0..<infoCount).map({ index in
			return ArchiveInfo(
				key: String(cString: unitsyncWrapper.GetInfoKey(index)),
				description: String(cString: unitsyncWrapper.GetInfoDescription(index)),
				value: infoValue(at: index)
			)
		})
	}

	private func loadOptions() -> [ArchiveOption] {
		return (0..<optionCount).map({ index in
			ArchiveOption(
				key: String(cString: unitsyncWrapper.GetOptionKey(index)),
				name: String(cString: unitsyncWrapper.GetOptionName(index)),
				description: String(cString: unitsyncWrapper.GetOptionDesc(index)),
				type: ArchiveOption.ValueType(rawValue: unitsyncWrapper.GetOptionType(index)),
				section: String(cString: unitsyncWrapper.GetOptionSection(index))
				// More TODO
			)
		})
	}

	private func loadDependencies() -> [UnitsyncArchive] {
		return (0..<archiveDependencyCount).map({ index in
			UnitsyncArchive(
				archiveIndex: index,
				archiveName: archiveDependencyName(at: index),
				unitsyncWrapper: unitsyncWrapper
			)
		})
	}

	// MARK: - Private helpers

	fileprivate func executeOnVFS<T>(_ block: () -> T) -> T {
		unitsyncWrapper.AddAllArchives(name.utf8CStringArray)
		let result = block()
		unitsyncWrapper.RemoveAllArchives()
		return result
	}

	// MARK: Overridable

	public var archiveName: String { fatalError() }
	fileprivate func archiveDependencyName(at index: CInt) -> String { fatalError() }
	fileprivate var archiveDependencyCount: CInt { fatalError() }
	fileprivate var infoCount: CInt { fatalError() }
	fileprivate var optionCount: CInt { fatalError() }

	// MARK: - Nested Types
	
	private func infoValue(at index: CInt) -> ArchiveInfo.Value? {
		let typeString = String(cString: unitsyncWrapper.GetInfoType(index))
		switch typeString.lowercased() {
		case "string":
			return .string(String(cString: unitsyncWrapper.GetInfoValueString(index)))
		case "integer":
			return .integer(Int(unitsyncWrapper.GetInfoValueInteger(index)))
		case "float":
			return .float(unitsyncWrapper.GetInfoValueFloat(index))
		case "bool":
			return .boolean(unitsyncWrapper.GetInfoValueBool(index))
		default:
			return nil
		}
	}
}

