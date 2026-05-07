import Foundation

enum ProductIDCatalog {
    enum Character {
        static let sena = "com.myteam.character.sena"
        static let kai = "com.myteam.character.kai"
        static let yuna = "com.myteam.character.yuna"
    }

    enum Subscription {
        static let proMonthly = "com.myteam.pro.monthly"
        static let proYearly = "com.myteam.pro.yearly"
    }

    static let allCharacters = [
        Character.sena,
        Character.kai,
        Character.yuna
    ]

    static let allSubscriptions = [
        Subscription.proMonthly,
        Subscription.proYearly
    ]

    static let all = allCharacters + allSubscriptions
}
