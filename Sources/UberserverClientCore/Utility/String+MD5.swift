//
//  String+MD5.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 25/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import CommonCrypto

extension String {
	/// Converts the string to md5-encrypted data.
	func md5() -> Data {
        let data = Data(self.utf8)
		var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
		CC_MD5((data as NSData).bytes, CC_LONG(data.count), &digest)
		return Data(digest)
	}
}
