import Foundation

public struct NilError: Error {
    let line: Int
    let file: StaticString
} 

public extension Optional {
    /**
      Throws `NilError`
     */
    func throwIfNil(line: Int = #line, file: StaticString = #file) throws -> Wrapped {
        guard case .some(let wrapped) = self else {
            throw NilError(line: line, file: file)
        }
        return wrapped
    }
}