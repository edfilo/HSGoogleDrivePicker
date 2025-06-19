
import UIKit
import GoogleSignIn
import GoogleSignInSwift   // UI helpers (optional)
import GoogleAPIClientForREST

/// Thin wrapper that mimics the old delegate-based API
/// but under the hood uses GoogleSignIn v7’s closure-based calls.
final class HSGoogleSignInBridge {

    static let shared = HSGoogleSignInBridge()

    /// - important: set this **once** in AppDelegate after `FirebaseApp.configure()`
    private(set) var configuration: GIDConfiguration!

    private init() {}

    /// Call **once** during app launch.
    func configure(clientID: String) {
        configuration = GIDConfiguration(clientID: clientID)
    }

    // MARK: – Sign-in / restore

    @discardableResult
    func signIn(from presentingVC: UIViewController,
                completion: @escaping (_ user: GIDGoogleUser?, _ error: Error?) -> Void) -> Void {

        guard let cfg = configuration else {
            completion(nil, NSError(domain: "HSGoogleDrivePicker",
                                    code: -42,
                                    userInfo: [NSLocalizedDescriptionKey: "HSGoogleSignInBridge not configured"]))
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC,
                                        hint: nil,
                                        additionalScopes: ["https://www.googleapis.com/auth/drive.readonly"]) { result, error in
            completion(result?.user, error)
        }
    }

    func restoreIfPossible(completion: @escaping (_ user: GIDGoogleUser?) -> Void) {
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, _ in
            completion(user)
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    func disconnect(completion: @escaping (_ error: Error?) -> Void) {
        GIDSignIn.sharedInstance.disconnect { error in
            completion(error)
        }
    }
}