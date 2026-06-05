//
//  UserProfileViewModel.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import Factory
import Foundation
import Observation

@Observable @MainActor
public final class UserProfileViewModel {
    public private(set) var profile: UserProfile?
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?

    private let service: UserProfileServiceProtocol
    private var hasLoadedOnce = false

    public init(service: UserProfileServiceProtocol) {
        self.service = service
    }

    public convenience init() {
        self.init(service: Container.shared.userProfileService())
    }

    public func load(force: Bool = false) async {
        if !force, hasLoadedOnce { return }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            profile = try await service.fetchProfile()
            hasLoadedOnce = true
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

    @discardableResult
    public func updateUsername(_ username: String) async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            self.profile = try await service.updateUsername(username)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update username."
            return false
        }
    }

    @discardableResult
    public func updateEmail(_ email: String) async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            self.profile = try await service.updateEmail(email)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update email."
            return false
        }
    }

    @discardableResult
    public func updatePassword(current: String, new: String) async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await service.updatePassword(current: current, new: new)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update password."
            return false
        }
    }

    @discardableResult
    public func deleteAccount() async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await service.deleteAccount()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to delete account."
            return false
        }
    }
}
