import ProjectDescription

// MARK: - Shared

let developmentTeam = "97W7A3Y9GD"

let commonSettings: SettingsDictionary = [
    "CODE_SIGN_STYLE": "Automatic",
    "DEVELOPMENT_TEAM": .string(developmentTeam),
    "SWIFT_VERSION": "6.0",
    "GENERATE_INFOPLIST_FILE": "YES",
]

// MARK: - Project

let project = Project(
    name: "WuhuDocViewDemo",
    settings: .settings(base: commonSettings),
    targets: [
        // macOS demo app
        .target(
            name: "WuhuDocViewDemo",
            destinations: .macOS,
            product: .app,
            bundleId: "ms.liu.wuhu.docview-demo",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .extendingDefault(with: [
                "NSMainStoryboardFile": "",
            ]),
            sources: ["Sources/**"],
            dependencies: [
                .external(name: "WuhuDocView"),
            ],
            settings: .settings(base: [
                "OTHER_LDFLAGS": [
                    "-Xlinker", "-interposable",
                ],
            ], defaultSettings: .recommended(excluding: [
                "CODE_SIGN_IDENTITY",
            ]))
        ),

        // iOS demo app
        .target(
            name: "WuhuDocViewDemoiOS",
            destinations: .iOS,
            product: .app,
            bundleId: "ms.liu.wuhu.docview-demo.ios",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationPortrait",
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight",
                ],
            ]),
            sources: ["Sources/**"],
            dependencies: [
                .external(name: "WuhuDocView"),
            ],
            settings: .settings(base: [
                "OTHER_LDFLAGS": [
                    "-Xlinker", "-interposable",
                ],
            ])
        ),
    ]
)
