import SwiftUI
import WidgetKit

@main
struct CoupleLifeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayTasksWidget()
        TodayStepsWidget()
        AnniversaryCountdownWidget()
    }
}
