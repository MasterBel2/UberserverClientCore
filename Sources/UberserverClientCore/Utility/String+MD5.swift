//
//  String+MD5.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 25/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import Crypto

extension String {
	/// Converts the string to md5-encrypted data.
	func md5() -> Data {
        return Data(Insecure.MD5.hash(data: Data(utf8)))
	}
}
