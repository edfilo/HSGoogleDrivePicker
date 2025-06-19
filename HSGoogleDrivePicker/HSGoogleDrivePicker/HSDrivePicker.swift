import UIKit
import GoogleSignIn
import GoogleAPIClientForREST

/// Navigation controller to present the File Viewer and Google-Drive picker UI.
/// Updated for GoogleSignIn v7+ (no more `GIDSignInDelegate`).
@objcMembers public class HSDrivePicker: UINavigationController {

    // MARK: – Public API

    /// Ask the picker to appear from the given view-controller.
    /// The completion returns the authorised manager and the file the user picked.
    public func pick(from presenter: UIViewController?,
                     withCompletion completion: @escaping (_ manager: HSDriveManager?, _ file: GTLRDrive_File?) -> Void) {
        viewer?.completion = completion
        viewer?.shouldSignInOnAppear = true
        presenter?.present(self, animated: true)
    }

    /// Handle OAuth callback URLs in AppDelegate:
    /// ```swift
    /// func application(_ app: UIApplication,
    ///                  open url: URL,
    ///                  options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    ///     return HSDrivePicker.handle(url)
    /// }
    /// ```
    public class func handle(_ url: URL?) -> Bool {
        guard let url else { return false }
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: – Initialisation

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    public init() {
        let viewer = HSDriveFileViewer()
        super.init(rootViewController: viewer)
        modalPresentationStyle = .pageSheet
        self.viewer = viewer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: – Private

    private var viewer: HSDriveFileViewer?

    /// Helper to download the *content* of a picked file after the user selects it.
    /// Call this on the authorised `GTLRDriveService` you get from `HSDriveManager`.
    func downloadFileContent(withService service: GTLRDriveService?,
                             file: GTLRDrive_File?,
                             completionBlock: @escaping (Data?, Error?) -> Void) {
        guard let downloadURL = file?.downloadURL else {
            completionBlock(nil, NSError(domain: NSURLErrorDomain,
                                         code: NSURLErrorBadURL,
                                         userInfo: nil))
            return
        }
        let fetcher = service?.fetcherService.fetcher(with: downloadURL)
        fetcher?.beginFetch { data, error in
            if let error {
                print("[HSDrivePicker] Download error: \(error)")
                completionBlock(nil, error)
            } else {
                completionBlock(data, nil)
            }
        }
    }

    // MARK: – Sign-In flow injected into the viewer
    // HSDriveFileViewer triggers sign-in via the bridge on appear.
    internal func ensureSignedIn(presenter: UIViewController,
                                 completion: @escaping (GIDGoogleUser?, Error?) -> Void) {
        // First try to restore silently
        HSGoogleSignInBridge.shared.restoreIfPossible { [weak presenter] restoredUser in
            if let user = restoredUser {
                completion(user, nil)
            } else if let presenter {
                // Present the sign-in sheet
                _ = HSGoogleSignInBridge.shared.signIn(from: presenter) { user, error in
                    completion(user, error)
                }
            } else {
                completion(nil, NSError(domain: "HSGoogleDrivePicker",
                                        code: -43,
                                        userInfo: [NSLocalizedDescriptionKey: "No presenter VC for sign-in"]))
            }
        }
    }
}
