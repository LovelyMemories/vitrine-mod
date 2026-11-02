// Flow's player: the band put on Spotify's full screen player and laid out with it.
//
// The controller is the one the redesign's player and its lyrics ride on (Redesigned/Player/
// PlayerLyrics.x), so the band is added on every pass of the player's layout and put into the room the
// cover has (Core/SGPlayerGeometry.h). Nothing of Spotify's is hidden or replaced: the title, the
// progress bar and the controls stay its own, with their actions and accessibility.
#import "Core/SGCore.h"
#import "FlowPlayer.h"

%hook _TtC19NowPlaying_ViewImpl24NowPlayingViewController

- (void)viewDidLayoutSubviews {
    %orig;
    UIView *host = ((UIViewController *)self).viewIfLoaded;
    // A player too short is not one: the same floor the redesign's lyrics use.
    if (!host || host.bounds.size.height < 400) return;
    SGFPlayerPanelIn(host);
    SGFPlayerPanelLayout(host);
}

%end

%ctor {
    if (!SGFlowUI()) return;
    %init;
    SGRequireClasses(@[@"_TtC19NowPlaying_ViewImpl24NowPlayingViewController"]);
}
