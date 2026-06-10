import SwiftUI

struct ThirdPartyLicensesView: View {
    private let attributionText: String = {
        if let url = Bundle.main.url(forResource: "Supertonic3Attribution", withExtension: "md"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return """
        Supertonic3

        Upstream: Supertone/supertonic-3
        Model license: OpenRAIL-M
        Sample code: MIT

        MyTeam does not claim user voice cloning support. Model redistribution and App Store distribution require separate approval before release.
        """
    }()

    var body: some View {
        ScrollView {
            Text(attributionText)
                .font(.system(.body, design: .default))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .navigationTitle("오픈소스 및 모델 고지")
    }
}
