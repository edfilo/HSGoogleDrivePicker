
import UIKit
import GoogleSignIn
//import GoogleSignInSwift   // UI helpers (optional)
import GoogleAPIClientForREST

/// Thin wrapper that mimics the old delegate-based API
/// but under the hood uses GoogleSignIn v7’s closure-based calls.
///
// MARK: – Legacy notification names (Objective-C visible)
@objc public class HSGoogleSignInNotifications: NSObject {
    @objc public static let signInFailed  =
        Notification.Name("hsGIDSignInFailedNotification")
    @objc public static let signInChanged =
        Notification.Name("hsGIDSignInChangedNotification")
}


@objcMembers                      // expose every method/property to Obj-C
public final class HSGoogleSignInBridge: NSObject {



    @objc public static let shared = HSGoogleSignInBridge()
    /// - important: set this **once** in AppDelegate after `FirebaseApp.configure()`
    private(set) var configuration: GIDConfiguration!

    private override init() {}

    /// Call **once** during app launch.
    @objc public func configure(clientID: String) {
        configuration = GIDConfiguration(clientID: clientID)
    }
    

    // MARK: - GTLR/Fetcher authorizer helper
    @objc public static var authorizer: GTMFetcherAuthorizationProtocol? {
        return GIDSignIn.sharedInstance.currentUser?.fetcherAuthorizer;
    }
    


    // MARK: – Sign-in / restore

    @discardableResult
    
    func signIn(from presentingVC: UIViewController,
                completion: @escaping (_ user: GIDGoogleUser?, _ error: Error?) -> Void) -> Bool {

        // 1. make sure we have a config
        guard let cfg = configuration else {
            let err = NSError(domain: "HSGoogleDrivePicker",
                              code: -42,
                              userInfo: [NSLocalizedDescriptionKey:
                                         "HSGoogleSignInBridge not configured (call configure(clientID:) first)"])
            completion(nil, err)
            return false
        }

        // 2. set it on the shared instance
        GIDSignIn.sharedInstance.configuration = cfg

        // 3. launch the Google sheet
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { result, error in
            if let user = result?.user, error == nil {

                let driveScope = "https://www.googleapis.com/auth/drive.readonly"

                if user.grantedScopes?.contains(driveScope) == true {
                    // scope already there
                    NotificationCenter.default.post(
                        name: HSGoogleSignInNotifications.signInChanged,
                        object: user)
                    completion(user, nil)

                } else {
                    // request the extra scope from *this* user
                    user.addScopes([driveScope],
                                   presenting: presentingVC) { signInResult, addError in
                        if let newUser = signInResult?.user, addError == nil {
                            NotificationCenter.default.post(
                                name: HSGoogleSignInNotifications.signInChanged,
                                object: newUser)
                            completion(newUser, nil)
                        } else {
                            NotificationCenter.default.post(
                                name: HSGoogleSignInNotifications.signInFailed,
                                object: addError)
                            completion(nil, addError)
                        }
                    }
                }

            } else {
                NotificationCenter.default.post(
                    name: HSGoogleSignInNotifications.signInFailed,
                    object: error)
                completion(nil, error)
            }
        }
        return true
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
