//
//  UserProfileViewModel.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import Combine
import Factory
import Foundation

public final class UserProfileViewModel: ObservableObject {
    @Published public private(set) var profile: UserProfile?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?

    private let service: UserProfileServiceProtocol

    public init(service: UserProfileServiceProtocol) {
        self.service = service
    }

    public convenience init() {
        self.init(service: Container.shared.userProfileService())
    }

    public func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            profile = try await service.fetchProfile()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load profile."
        }
    }

    @discardableResult
    public func save(profile: UserProfile) async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            self.profile = try await service.updateProfile(profile)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to save profile."
            return false
        }
    }
}
