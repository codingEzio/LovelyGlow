import Testing
@testable import LovelyGlowCore

struct SpaceOverviewTests {
    @Test func cmdTabDockOnTheUserSpaceKeepsThePreviousGlow() {
        #expect(
            SpaceOverview.shouldHideGlow(
                spaceType: SpaceOverview.userSpace,
                frontIsSystemChrome: true
            ) == false
        )
    }

    @Test func missionControlSystemSpaceHidesGlow() {
        #expect(
            SpaceOverview.shouldHideGlow(
                spaceType: SpaceOverview.systemSpace,
                frontIsSystemChrome: true
            )
        )
    }

    @Test func windowLayoutAnimationIsNotMissionControl() {
        #expect(
            SpaceOverview.shouldHideGlow(
                spaceType: SpaceOverview.userSpace,
                frontIsSystemChrome: false
            ) == false
        )
    }

    @Test func nonUserSpaceWithDockFrontIsOverview() {
        #expect(
            SpaceOverview.shouldHideGlow(
                spaceType: 4,
                frontIsSystemChrome: true
            )
        )
    }

    @Test func fullscreenAppSpaceHidesGlow() {
        #expect(
            SpaceOverview.shouldHideGlow(
                spaceType: SpaceOverview.tiledSpace,
                frontIsSystemChrome: false
            )
        )
        #expect(
            SpaceOverview.shouldHideGlow(
                spaceType: SpaceOverview.fullscreenSpace,
                frontIsSystemChrome: false
            )
        )
        #expect(SpaceOverview.isExclusive(SpaceOverview.fullscreenSpace))
        #expect(SpaceOverview.isExclusive(SpaceOverview.tiledSpace))
        #expect(SpaceOverview.isExclusive(SpaceOverview.systemSpace))
        #expect(!SpaceOverview.isExclusive(SpaceOverview.userSpace))
        #expect(SpaceOverview.shouldRejoin(spaceType: SpaceOverview.userSpace))
        #expect(!SpaceOverview.shouldRejoin(spaceType: SpaceOverview.fullscreenSpace))
        #expect(!SpaceOverview.shouldRejoin(spaceType: SpaceOverview.tiledSpace))
    }
}
