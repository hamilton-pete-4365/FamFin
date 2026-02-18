import WidgetKit
import SwiftUI

@main
struct FamFinWidgetBundle: WidgetBundle {
    var body: some Widget {
        ToBudgetWidget()
        AccountsWidget()
        BudgetOverviewWidget()
    }
}
