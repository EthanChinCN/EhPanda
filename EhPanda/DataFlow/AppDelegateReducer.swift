//
//  AppDelegateReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import SwiftUI
import SwiftyBeaver
import ComposableArchitecture

struct AppDelegateReducer: Reducer {
    struct State: Equatable {
        var migrationState = MigrationReducer.State()
    }

    enum Action: Equatable {
        case onLaunchFinish
        case removeExpiredImageURLs

        case migration(MigrationReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.libraryClient) private var libraryClient
    @Dependency(\.cookieClient) private var cookieClient

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .onLaunchFinish:
                return .merge(
                    .run { _ in
                        libraryClient.initializeLogger()
                    },
                    .run { _ in
                        libraryClient.initializeWebImage()
                    },
                    .run { _ in
                        cookieClient.removeYay()
                    },
                    .run { _ in
                        cookieClient.syncExCookies()
                    },
                    .run { _ in
                        cookieClient.ignoreOffensive()
                    },
                    .run { _ in
                        cookieClient.fulfillAnotherHostField()
                    },
                    .send(.migration(.prepareDatabase))
                )

            case .removeExpiredImageURLs:
                return .run { _ in
                    await databaseClient.removeExpiredImageURLs()
                }

            case .migration:
                return .none
            }
        }

        Scope(state: \.migrationState, action: /Action.migration, child: MigrationReducer.init)
    }
}

// MARK: AppDelegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    let store = Store(initialState: .init()) {
        AppReducer()
    }
    lazy var viewStore = ViewStore(store, observe: { $0 })

    static var orientationMask: UIInterfaceOrientationMask = DeviceUtil.isPad ? .all : [.portrait, .portraitUpsideDown]

    func application(
        _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask { AppDelegate.orientationMask }

    func application(
        _ application: UIApplication, didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if !AppUtil.isTesting {
            viewStore.send(.appDelegate(.onLaunchFinish))
        }
        return true
    }
}
