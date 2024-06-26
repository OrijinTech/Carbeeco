//
//  AuthServices.swift
//  DH_App
//
//  Created by Yongxiang Jin on 3/10/24.
//

import Foundation
import Firebase
import FirebaseFirestoreSwift
import AuthenticationServices


// MARK: FUNCTIONS WHICH TAKES CARE OF THE AUTHENTICATION NETWORKING TASKS.
class AuthServices {
    @Published var userSession: FirebaseAuth.User?
    static let sharedAuth = AuthServices()
    
    init() {
        self.userSession = Auth.auth().currentUser // In charge of taking the user to either welcome view or main menu if they are signed in
        Task { try await UserServices.sharedUser.fetchCurrentUserData() } // Get user data
    }
    
    
    // MARK: Sign in using email and password
    @MainActor
    func login(withEmail email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            try await UserServices.sharedUser.fetchCurrentUserData()
            print("LOGGED IN USER WITH EMAIL AND PASSWORD \n\(result.user.uid)" )
        } catch {
            print("ERROR: FAILED TO SIGN IN WITH EMAIL AND PASSWORD! \nSource: AuthServices/login() \n\(error)")
        }
    }

    
    // MARK: Sign in using credential (for Google and Apple Sign in)
    @MainActor
    func login(credential: AuthCredential) async throws {
        do {
            let result = try await Auth.auth().signIn(with: credential)
            print("LOGIN WITH CREDENTIAL: \nGOT RESULT: \(result.user.uid)")
            self.userSession = result.user
            try await UserServices.sharedUser.fetchCurrentUserData()
            print("LOGGED IN USER WITH CREDENTIAL: \n\(result.user.uid)" )
        } catch {
            // TODO: Make sure this is also true for Apple Sign In
            let result = try await Auth.auth().signIn(with: credential)
            try await self.uploadUserData(email: result.user.email!, userName: "Cool Person \(result.user.uid.lowercased().prefix(6))", id: result.user.uid)
            print("ERROR: FAILED TO SIGN IN WITH CREDENTIAL! \nSource: AuthServices/login() \n\(error.localizedDescription)")
        }
    }
    
    
    // MARK: Calling the login with credential (another sign in method)
    @MainActor
    func loginWithGoogle(tokens: GoogleSignInModel) async throws {
        let credential = GoogleAuthProvider.credential(withIDToken: tokens.idToken, accessToken: tokens.accessToken)
        try await login(credential: credential)
    }
    
    // MARK: Calling the login with credential
    @MainActor
    func loginWithApple(credential: OAuthCredential) async throws {
        try await login(credential: credential)
    }
    
    
    
    // MARK: This is called when creating a new user through the Registration View Model
    @MainActor
    func createUser(withEmail email: String, password: String, username: String) async throws {
        do{
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            try await self.uploadUserData(email: email, userName: username, id: result.user.uid)
            print("CREATED USER \(result.user.uid)" )
        } catch {
            print("ERROR: FAILED TO CREATE USER \nSource: AuthServices/createUser() \n\(error.localizedDescription)") //automatically gives us the "error" object by swift
        }
    }
    
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            UserServices.sharedUser.reset() // Set currentUser object to nil
        } catch {
            print("ERROR: FAILED TO SIGN OUT \nSource: AuthServices/signOut \n\(error.localizedDescription)")
        }
    }
    
    
    func resetPassword(with email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("SENT AN EMAIL TO THE ADDRESS: \(email)" )
        } catch {
            print("ERROR: FAILED TO SEND RESET EMAIL \nSource: AuthServices/resetPassword() \n\(error.localizedDescription)")
        }
    }
    
    
    // MARK: Uploading the user data after creating an account.
    @MainActor // Same as Dispatchqueue.main.async
    private func uploadUserData(email: String, userName: String?, id: String) async throws {
        let user = User(email: email, userName: userName!, profileImageUrl: nil)
        guard let encodeUser = try? Firestore.Encoder().encode(user) else { return }
        try await Firestore.firestore().collection(Collection().user).document(id).setData(encodeUser)
        UserServices.sharedUser.currentUser = user
    }
    
}
