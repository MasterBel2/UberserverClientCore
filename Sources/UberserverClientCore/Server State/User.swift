//
//  User.swift
//  BelieveAndRise
//
//  Created by MasterBel2 on 24/6/19.
//  Copyright © 2019 MasterBel2. All rights reserved.
//

import Foundation
import CountryCode

public final class User {
	
	public init(profile: Profile) {
		self.profile = profile
	}
	
	/// The user's profile as contained on the server
	public let profile: Profile
    public var status = Status.default
	
	/// The user's ID.
	public var id: Int { return profile.id }
	
	public struct Profile {
		public let id: Int
		/// The full, unmodified username. Use this when describing a user to the server.
        public let fullUsername: String
        public let clans: [String]
		/// The user's username, with the leading clan tag (if any) removed. Do not use this when communicating with the server; only use this when displaying information to your user.
        public let username: String
        /// A string identifying which lobby client the user is using
        public var lobbyID: String
        public let country: CountryCode?

        public init(id: Int, fullUsername: String, lobbyID: String, country: CountryCode?) {
            self.id = id
            self.lobbyID = lobbyID
            self.fullUsername = fullUsername
            self.country = country

            guard let regex = try? NSRegularExpression(pattern: "\\[.+?\\]") else {
                self.clans = []
                username = fullUsername
                return
            }

            let tagRanges = regex.matches(
                in: fullUsername,
                range: NSRange(fullUsername.startIndex..., in: fullUsername)
            ).compactMap({ Range($0.range, in: fullUsername) })

            self.clans = tagRanges.map({ range in String(fullUsername[range]) })

            var username = ""
            var startIndex = fullUsername.startIndex
            if tagRanges.count > 0 {
                for tagRange in tagRanges {
                    username.append(String(fullUsername[startIndex..<tagRange.lowerBound]))
                    startIndex = tagRange.upperBound
                }
            }
            username.append(String(fullUsername[startIndex..<fullUsername.endIndex]))
            self.username = username
        }
    }

    public struct Status {
        /// Indicates whether the user is AFK.
        public let isAway: Bool
        public let isIngame: Bool
        public let rank: Int
        let isModerator: Bool
        /// Indicates whether the account is automated.
		///
		/// An automated account is usually referred to as a "Bot" in the context of the SpringRTS lobby server.
		/// This property is also referred to as a "botflag".
		let isAutomatedAccount: Bool
		#warning("""
        Whether a user account is automated should be sent as part of the log-on profile,
        not as part of the continually-updating status.
        """)

        public func changing(
            isAway: Bool? = nil,
            isIngame: Bool? = nil
        ) -> Status {
            return Status(
                isAway: isAway ?? self.isAway,
                isIngame: isIngame ?? self.isIngame,
                rank: rank,
                isModerator: isModerator,
                isAutomatedAccount: isAutomatedAccount
            )
        }

        static var `default`: Status {
            return Status(rawValue: 0)
        }
		
		init(isAway: Bool, isIngame: Bool, rank: Int, isModerator: Bool, isAutomatedAccount: Bool) {
			self.isAway = isAway
			self.isIngame = isIngame
			self.rank = rank
			self.isModerator = isModerator
			self.isAutomatedAccount = isAutomatedAccount
		}
		
		init(rawValue: Int) {
			isIngame = (rawValue & 0b01) == 1
			isAway = (rawValue & 0b10) >> 1 == 1
			rank = (rawValue & 0b11100) >> 2
			isModerator = (rawValue & (1 << 4)) == 1
			isAutomatedAccount = (rawValue & (1 << 5)) == 1
		}
		
		var rawValue: Int {
			var value = 0
			value += isIngame ? 1 : 0
			value += isIngame ? 2 : 0
			value += rank << 2
			value += isModerator ? 8 : 0
			value += isAutomatedAccount ? 16 : 0
			
			return value
		}
	}
}
