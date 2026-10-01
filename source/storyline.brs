function BuildStoryline() as Object
    return {
        initialRoute: "boot"
        routes: {
            boot: {
                component: "BootScreen"
                on: {
                    complete: "dedication"
                    cancel: "mainMenu"
                }
            }
            dedication: {
                component: "IntertitleScreen"
                params: {
                    text: "Dedicated to the early-'90s demoscene."
                    holdMs: 2500
                }
                on: {
                    complete: "mainMenu"
                    cancel: "mainMenu"
                }
            }
            mainMenu: {
                component: "MainMenuScreen"
                on: {
                    playAll: "exhibitIntro"
                    quickGuide: "quickGuide"
                    browse: "explore"
                    cancel: "mainMenu"
                }
            }
            exhibitIntro: {
                component: "ExhibitScreen"
                on: {
                    play: "player"
                    advance: "exhibitIntro"
                    backToMenu: "mainMenu"
                    backToGrid: "explore"
                }
            }
            player: {
                component: "PlayerScreen"
                on: {
                    advance: "exhibitIntro"
                    backToInfo: "exhibitIntro"
                    endToMenu: "mainMenu"
                    endToGrid: "explore"
                }
            }
            quickGuide: {
                component: "QuickGuideScreen"
                on: {
                    complete: "mainMenu"
                    cancel: "mainMenu"
                }
            }
            explore: {
                component: "ExploreScreen"
                on: {
                    selectExhibit: "exhibitIntro"
                    cancel: "mainMenu"
                }
            }
        }
    }
end function
