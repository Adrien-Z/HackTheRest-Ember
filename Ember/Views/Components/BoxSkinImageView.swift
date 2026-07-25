import SwiftUI

struct BoxSkinImageView: View {
    let decoration: BoxDecoration?
    let size: CGSize

    init(
        decoration: BoxDecoration?,
        size: CGSize = CGSize(width: 70, height: 70)
    ) {
        self.decoration = decoration
        self.size = size
    }

    var body: some View {
        Image(decoration?.assetName ?? "basic_blue")
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
    }
}

struct BoxSkinImageView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 18) {
            BoxSkinImageView(decoration: nil)
            BoxSkinImageView(
                decoration: BoxDecoration(
                    id: "sleepy-blue",
                    name: "Sleepy Blue",
                    assetName: "sleepy_blue",
                    requiredScore: 500),
                size: CGSize(width: 120, height: 120))
        }
        .padding()
        .background(NightBackground())
        .preferredColorScheme(.dark)
    }
}
