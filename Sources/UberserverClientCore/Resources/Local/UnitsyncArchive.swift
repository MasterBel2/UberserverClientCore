//
//  UnitsyncArchive.swift
//  
//
//  Created by MasterBel2 on 3/2/21.
//

import Foundation

// MARK: - Maps

final public class UnitsyncMapArchive: UnitsyncArchive, MapArchive, QueueLockable {

	public struct Args {
		let name: String
		let index: CInt
		let minimapLoadQueue: DispatchQueue
	}

	let minimapLoadQueue: DispatchQueue

	public required init(args: Args, threadUnsafeObjectLockedToSameQueue: UnitsyncWrapper) {
		self.minimapLoadQueue = args.minimapLoadQueue
		super.init(archiveIndex: args.index, archiveName: args.name, unitsyncWrapper: threadUnsafeObjectLockedToSameQueue)
	}

	// MARK: Properties

    public private(set) lazy var heightRange: ClosedRange<Float> = { unitsyncWrapper.GetMapMinHeight(name.utf8CStringArray)...unitsyncWrapper.GetMapMaxHeight(name.utf8CStringArray) }()

	/// A value of 0 indicates a failure to load the value - which should never happen.
    public private(set) lazy var width: Int = {
		guard let value = info.first(where: { $0.key == "width" })?.value,
			  case let .integer(width) = value else {
			return 0
		}
		return width
	}()
	/// A value of 0 indicates a failure to load the value - which should never happen.
    public private(set) lazy var height: Int = {
		guard let value = info.first(where: { $0.key == "height" })?.value,
			  case let .integer(width) = value else {
			return 0
		}
		return width
	}()
	public private(set) lazy var grassMap: InfoMap = { InfoMap<UInt8>(name: .grass, loadSize: loadInfoMapSize(infoMapName:), loadPixels: loadInfoMapPixels(infoMapName:loadDestination:)) }()
	public private(set) lazy var heightMap: InfoMap = { InfoMap<UInt16>(name: .height, loadSize: loadInfoMapSize(infoMapName:), loadPixels: loadInfoMapPixels(infoMapName:loadDestination:)) }()
	public private(set) lazy var metalMap: InfoMap = { InfoMap<UInt8>(name: .metal, loadSize: loadInfoMapSize(infoMapName:), loadPixels: loadInfoMapPixels(infoMapName:loadDestination:)) }()
	public private(set) lazy var typeMap: InfoMap = { InfoMap<UInt8>(name: .type, loadSize: loadInfoMapSize(infoMapName:), loadPixels: loadInfoMapPixels(infoMapName:loadDestination:)) }()
    public private(set) lazy var fileName: String = { String(cString: unitsyncWrapper.GetMapFileName(archiveIndex) )}()
    public private(set) lazy var completeChecksum: Int32 = { unitsyncWrapper.GetMapChecksum(archiveIndex) }()

	// MARK: Overrides

	public override var checksum: Int32 {
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
	
	private func loadInfoMapSize<T>(infoMapName: InfoMap<T>.Name) -> (width: Int, height: Int) {
		let cName = infoMapName.rawValue.cString(using: .utf8)!
		var height = CInt()
		var width = CInt()
		_ = unitsyncWrapper.GetInfoMapSize(name, cName, &width, &height)
		if width == 0 {
			Logger.log(String(cString: unitsyncWrapper.GetNextError()), tag: .GeneralError)
		}
		return (width: Int(width), height: Int(height))
	}
	
	private func loadInfoMapPixels<T>(infoMapName: InfoMap<T>.Name, loadDestination: UnsafeMutablePointer<UInt8>) {
		_ = unitsyncWrapper.GetInfoMap(name, infoMapName.rawValue, loadDestination, CInt(MemoryLayout<T>.size))
	}
	
	private func loadMinimapPixels(mipLevel: Int, count: Int) -> [RGB565Color] {
        let minimapPointer = unitsyncWrapper.GetMinimap(name, CInt(mipLevel))
		return Array(UnsafeBufferPointer(start: minimapPointer, count: count))
	}

	private var mipLevels: [Int : [RGB565Color]] = [:]

	public func minimap(for mipLevel: Int) -> [RGB565Color] {
		guard mipLevel < 9 else {
			fatalError("Cannot handle a mip level larger than 8")
		}
		if let data = mipLevels[mipLevel] {
			return data
		}
		let factor = 1024 / Int(pow(2, Float(mipLevel)))
		let data = loadMinimapPixels(mipLevel: mipLevel, count: factor * factor)
		mipLevels[mipLevel] = data
		return data
	}
    
    public func loadMinimaps(mipLevels: Range<Int>, completionBlock: @escaping ((data: [UInt16], dimension: Int)?) -> Void) {
		for (index, mipLevel) in mipLevels.enumerated() {
			if let data = self.mipLevels[mipLevel] {
				completionBlock((data, 1024 / Int(pow(2, Float(mipLevel)))))
				let invertedIndex = mipLevels.count - index
				guard index != 0 else {
					break
				}
				
				for mipLevel in mipLevels[invertedIndex..<mipLevels.count] {
					completionBlock((minimap(for: mipLevel), 1024 / Int(pow(2, Float(mipLevel)))))
				}

				break
			}
		}
    }
}

// MARK: - Mods

final public class UnitsyncModArchive: UnitsyncArchive, ModArchive, QueueLockable {

	public required init(args: CInt, threadUnsafeObjectLockedToSameQueue: UnitsyncWrapper) {
		super.init(archiveIndex: args, archiveName: nil, unitsyncWrapper: threadUnsafeObjectLockedToSameQueue)
	}
	
	// MARK: Properties

    public private(set) lazy var completeChecksum: Int32 = { unitsyncWrapper.GetPrimaryModChecksum(archiveIndex) }()

	public private(set) lazy var factions: [Faction] = {
		return executeOnVFS {
			let sideCount = unitsyncWrapper.GetSideCount()

			guard sideCount > 0 else { return [] }
            return (0..<sideCount).map({ index in
				return Faction(
                    name: String(cString: unitsyncWrapper.GetSideName(index)),
                    startUnit: String(cString: unitsyncWrapper.GetSideStartUnit(index))
				)
			})
		}
	}()
	
	// MARK: Overrides

	public override var archiveName: String {
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

final public class UnitsyncSkirmishAIArchive: UnitsyncArchive, SkirmishAIArchive, QueueLockable {
	
	public required init(args: CInt, threadUnsafeObjectLockedToSameQueue: UnitsyncWrapper) {
		super.init(archiveIndex: args, archiveName: nil, unitsyncWrapper: threadUnsafeObjectLockedToSameQueue)
	}
	
	override var archiveDependencyCount: CInt {
		return 0
	}

	override var infoCount: CInt {
        return unitsyncWrapper.GetSkirmishAIInfoCount(archiveIndex)
	}

	override var optionCount: CInt {
        return unitsyncWrapper.GetSkirmishAIOptionCount(archiveIndex)
	}

	public override var archiveName: String {
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

	public init(archiveIndex: CInt, archiveName: String?, unitsyncWrapper: UnitsyncWrapper) {
		self.archiveIndex = archiveIndex
		self.unitsyncWrapper = unitsyncWrapper

		if let archiveName = archiveName {
			self.name = archiveName
		}
	}

	fileprivate let unitsyncWrapper: UnitsyncWrapper

	let archiveIndex: CInt
	public private(set) lazy var name: String = archiveName
    public private(set) lazy var path: String = { String(cString: unitsyncWrapper.GetArchivePath(name.utf8CStringArray) ) }()
    public private(set) lazy var singleArchiveChecksum: Int32 = { unitsyncWrapper.GetArchiveChecksum(name.utf8CStringArray) }()

	public var checksum: Int32 { return singleArchiveChecksum }

	public private(set) lazy var info = loadInfo()
	public private(set) lazy var dependencies = loadDependencies()
	public private(set) lazy var options = loadOptions()

	// MARK: - Loading data

	private func loadInfo() -> [ArchiveInfo] {
		return (0..<infoCount).compactMap({ index in
			guard let value = infoValue(at: index) else { return nil }
			return ArchiveInfo(
                key: String(cString: unitsyncWrapper.GetInfoKey(index)),
                description: String(cString: unitsyncWrapper.GetInfoDescription(index)),
				value: value
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

