import Foundation

/// Draft copy: needs Fernando's verdict before prod.
public enum RecapArchetype: String, Codable, Sendable, Equatable, CaseIterable {
    case copycatStrategist = "copycat_strategist"
    case dividendFarmer = "dividend_farmer"
    case saver
    case comebackKid = "comeback_kid"
    case tickerHunter = "ticker_hunter"
    case researcher
    case disciplinedSizer = "disciplined_sizer"
    case patientPlanner = "patient_planner"
    case steadyBuilder = "steady_builder"

    public var title: String {
        switch self {
        case .copycatStrategist: "The Copycat Strategist"
        case .dividendFarmer: "The Dividend Farmer"
        case .saver: "The Saver"
        case .comebackKid: "The Comeback Kid"
        case .tickerHunter: "The Ticker Hunter"
        case .researcher: "The Researcher"
        case .disciplinedSizer: "The Disciplined Sizer"
        case .patientPlanner: "The Patient Planner"
        case .steadyBuilder: "The Steady Builder"
        }
    }

    public var tagline: String {
        switch self {
        case .copycatStrategist: "You studied the pros and moved with them."
        case .dividendFarmer: "You planted shares and harvested payouts."
        case .saver: "Steady deposits, goal by goal."
        case .comebackKid: "Slow start, strong finish."
        case .tickerHunter: "No chart went unturned."
        case .researcher: "Thesis first, trade later."
        case .disciplinedSizer: "Targets set, emotions parked."
        case .patientPlanner: "You showed up often and traded rarely."
        case .steadyBuilder: "Brick by brick, you built the habit."
        }
    }
}
