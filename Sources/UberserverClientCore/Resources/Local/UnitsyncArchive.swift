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

    private(set) lazy var heightRange: ClosedRange<Float> = { unitsyncWrapper.sync { $0.GetMapMinHeight(name.utf8CStringArray) }...unitsyncWrapper.sync { $0.GetMapMaxHeight(name.utf8CStringArray) } }()

    private(set) lazy var width: Int = { Int(unitsyncWrapper.sync { $0.GetMapWidth(archiveIndex) }) }()
    private(set) lazy var height: Int = { Int(unitsyncWrapper.sync { $0.GetMapHeight(archiveIndex) }) }()
	private(set) lazy var grassMap: InfoMap = { InfoMap<UInt8>(name: .grass, loadSize: loadInfoMapSize(infoMapName:), loadPixels: loadInfoMapPixels(infoMapName:loadDestination:)) }()
	private(set) lazy var heightMap: InfoMap = { InfoMap<UInt16>(name: .height, loadSize: loadInfoMapSize(infoMapName:), loadPixels: loadInfoMapPixels(infoMapName:loadDestination:)) }()
	private(set) lazy var metalMap: InfoMap = { InfoMap<UInt8>(name: .metal, loadSize: loadInfoMapSize(infoMapName:), loadPixels: loadInfoMapPixels(infoMapName:loadDestination:)) }()
	private(set) lazy var typeMap: InfoMap = { InfoMap<UInt8>(name: .type, loadSize: loadInfoMapSize(infoMapName:), loadPixels: loadInfoMapPixels(infoMapName:loadDestination:)) }()
	private(set) lazy var miniMap: Minimap = { Minimap(loadPixels: loadMinimapPixels(mipLevel:count:)) }()
    private(set) lazy var fileName: String = { String(cString: unitsyncWrapper.sync { $0.GetMapFileName(archiveIndex) } )}()
    private(set) lazy var completeChecksum: Int32 = { unitsyncWrapper.sync { $0.GetMapChecksum(archiveIndex) } }()

	// MARK: Overrides

	override var checksum: Int32 {
		return completeChecksum
	}

	override var optionCount: CInt {
        return unitsyncWrapper.sync { $0.GetMapOptionCount(name.utf8CStringArray) }
	}
	override func archiveDependencyName(at index: CInt) -> String {
        String(cString: unitsyncWrapper.sync { $0.GetMapArchiveName(index) })
	}
	override var archiveDependencyCount: CInt {
        return unitsyncWrapper.sync { $0.GetMapArchiveCount(name.utf8CStringArray) }
	}
	override var infoCount: CInt {
        unitsyncWrapper.sync { $0.GetMapInfoCount(archiveIndex) }
	}
	
	// MARK: Unitsync
	
	func loadInfoMapSize<T>(infoMapName: InfoMap<T>.Name) -> (width: Int, height: Int) {
		let cName = infoMapName.rawValue.cString(using: .utf8)!
		var height = CInt()
		var width = CInt()
		withUnsafePointer(to: cName[0]) { cNamePointer in
            _ = unitsyncWrapper.sync { $0.GetInfoMapSize(name, cNamePointer, &width, &height) }
		}
		return (width: Int(width), height: Int(height))
	}
	
	func loadInfoMapPixels<T>(infoMapName: InfoMap<T>.Name, loadDestination: UnsafeMutablePointer<UInt8>) {
		let cName = infoMapName.rawValue.cString(using: .utf8)!
		withUnsafePointer(to: cName[0]) { cName in
            _ = unitsyncWrapper.sync { $0.GetInfoMap(name, cName, loadDestination, CInt(MemoryLayout<T>.size)) }
		}
	}
	
	func loadMinimapPixels(mipLevel: Int, count: Int) -> [RGB565Color] {
        let minimapPointer = unitsyncWrapper.sync { $0.GetMinimap(name, CInt(mipLevel)) }
		return Array(UnsafeBufferPointer(start: minimapPointer, count: count))
	}
}

// MARK: - Mods

final class UnitsyncModArchive: UnitsyncArchive, ModArchive {
	
	// MARK: Properties

    private(set) lazy var completeChecksum: Int32 = { unitsyncWrapper.sync { $0.GetPrimaryModChecksum(archiveIndex) } }()

	private(set) lazy var factions: [Faction] = {
		return executeOnVFS {
            return (0..<unitsyncWrapper.sync { $0.GetSideCount() }).map({ index in
				return Faction(
                    name: String(cString: unitsyncWrapper.sync { $0.GetSideName(index) }),
                    startUnit: String(cString: unitsyncWrapper.sync { $0.GetSideStartUnit(index) })
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
        return String(cString: unitsyncWrapper.sync { $0.GetPrimaryModArchiveList(index) })
	}

	override var archiveDependencyCount: CInt {
        return unitsyncWrapper.sync { $0.GetPrimaryModArchiveCount(archiveIndex) }
	}

	override var infoCount: CInt {
        return unitsyncWrapper.sync { $0.GetPrimaryModInfoCount(archiveIndex) }
	}

	override var optionCount: CInt {
		return executeOnVFS {
            return unitsyncWrapper.sync { $0.GetModOptionCount() }
		}
	}
}

// MARK: - Skirmish AIs

final class UnitsyncSkirmishAIArchive: UnitsyncArchive, SkirmishAIArchive {
	override var archiveDependencyCount: CInt {
		return 0
	}

	override var infoCount: CInt {
        return unitsyncWrapper.sync { $0.GetSkirmishAIInfoCount(archiveIndex) }
	}

	override var optionCount: CInt {
        return unitsyncWrapper.sync { $0.GetSkirmishAIOptionCount(archiveIndex) }
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
	init(archiveIndex: CInt, archiveName: String, unitsyncWrapper: QueueLocked<UnitsyncWrapper>) {
		self.unitsyncWrapper = unitsyncWrapper
		self.archiveIndex = archiveIndex
		self.name = archiveName
	}
	init(archiveIndex: CInt, unitsyncWrapper: QueueLocked<UnitsyncWrapper>) {
		self.unitsyncWrapper = unitsyncWrapper
		self.archiveIndex = archiveIndex
	}

	let unitsyncWrapper: QueueLocked<UnitsyncWrapper>

	let archiveIndex: CInt
	public private(set) lazy var name: String = archiveName
    public private(set) lazy var path: String = { String(cString: unitsyncWrapper.sync { $0.GetArchivePath(name.utf8CStringArray) }) }()
    public private(set) lazy var singleArchiveChecksum: Int32 = { unitsyncWrapper.sync { $0.GetArchiveChecksum(name.utf8CStringArray) } }()

	public var checksum: Int32 { return singleArchiveChecksum }

	public private(set) lazy var info = loadInfo()
	public private(set) lazy var dependencies = loadDependencies()
	public private(set) lazy var options = loadOptions()

	// MARK: - Loading data

	private func loadInfo() -> [ArchiveInfo] {
		return (0..<infoCount).map({ index in
			return ArchiveInfo(
                key: String(cString: unitsyncWrapper.sync { $0.GetInfoKey(index) }),
                description: String(cString: unitsyncWrapper.sync { $0.GetInfoDescription(index) }),
				value: infoValue(at: index)
			)
		})
	}

	private func loadOptions() -> [ArchiveOption] {
		return (0..<optionCount).map({ index in
			ArchiveOption(
                key: String(cString: unitsyncWrapper.sync { $0.GetOptionKey(index) }),
                name: String(cString: unitsyncWrapper.sync { $0.GetOptionName(index) }),
                description: String(cString: unitsyncWrapper.sync { $0.GetOptionDesc(index) }),
                type: ArchiveOption.ValueType(rawValue: unitsyncWrapper.sync { $0.GetOptionType(index) }),
                section: String(cString: unitsyncWrapper.sync { $0.GetOptionSection(index) })
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
        unitsyncWrapper.sync { $0.AddAllArchives(name.utf8CStringArray) }
		let result = block()
        unitsyncWrapper.sync { $0.RemoveAllArchives() }
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
        let typeString = String(cString: unitsyncWrapper.sync { $0.GetInfoType(index) })
		switch typeString.lowercased() {
		case "string":
            return .string(String(cString: unitsyncWrapper.sync { $0.GetInfoValueString(index) }))
		case "integer":
            return .integer(Int(unitsyncWrapper.sync { $0.GetInfoValueInteger(index) }))
		case "float":
            return .float(unitsyncWrapper.sync { $0.GetInfoValueFloat(index) })
		case "bool":
            return .boolean(unitsyncWrapper.sync { $0.GetInfoValueBool(index) })
		default:
			return nil
		}
	}
}

