import Foundation

struct MariaProxyRequest: Codable {
    let userId: String
    let userMessage: String
    let context: BalanceContext
}

struct MariaProxyResponse: Codable {
    let responseText: String
    let tokensUsed: Int
}
