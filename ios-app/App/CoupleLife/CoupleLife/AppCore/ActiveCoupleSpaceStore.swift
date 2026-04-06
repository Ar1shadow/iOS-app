import Foundation

final class UserDefaultsActiveCoupleSpaceStore: ActiveCoupleSpaceStore {
    private enum Keys {
        static let activeCoupleSpaceId = "couple.activeSpace.id"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var activeCoupleSpaceId: String? {
        get { userDefaults.string(forKey: Keys.activeCoupleSpaceId) }
        set {
            guard let newValue else {
                userDefaults.removeObject(forKey: Keys.activeCoupleSpaceId)
                return
            }

            userDefaults.set(newValue, forKey: Keys.activeCoupleSpaceId)
        }
    }
}
