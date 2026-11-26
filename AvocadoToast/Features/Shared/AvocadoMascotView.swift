//
//  AvocadoMascotView.swift
//  AvocadoToast
//
//  Small original vector mascot illustrations for empty and error states.
//

import SwiftUI

struct AvocadoMascotView: View {
    enum Mood: Equatable {
        case emptyToaster
        case searching
        case playbackError
        case importing
    }

    let mood: Mood

    private var avocado: Color { Color(red: 0.27, green: 0.48, blue: 0.25) }
    private var flesh: Color { Color(red: 0.72, green: 0.82, blue: 0.43) }
    private var pit: Color { Color(red: 0.48, green: 0.29, blue: 0.17) }
    private var toaster: Color { Color(red: 0.72, green: 0.70, blue: 0.64) }
    private var ink: Color { Color(red: 0.16, green: 0.19, blue: 0.14) }

    var body: some View {
        Canvas { context, size in
            var drawing = context
            drawing.scaleBy(x: size.width / 240, y: size.height / 180)

            switch mood {
            case .emptyToaster:
                drawToaster(in: &drawing)
                drawAvocado(in: &drawing, lookingRight: true)
                drawLongingArms(in: &drawing)
            case .searching:
                drawMagnifyingGlass(in: &drawing)
                drawAvocado(in: &drawing, lookingRight: true)
                drawQuestionMark(in: &drawing)
            case .playbackError:
                drawAvocado(in: &drawing, lookingRight: false)
                drawBrokenNote(in: &drawing)
                drawOopsStars(in: &drawing)
            case .importing:
                drawFolder(in: &drawing)
                drawAvocado(in: &drawing, lookingRight: true)
                drawMusicNotes(in: &drawing)
            }
        }
        .frame(width: 240, height: 180)
        .accessibilityHidden(true)
    }

    private func drawAvocado(in context: inout GraphicsContext, lookingRight: Bool) {
        var bodyPath = Path()
        bodyPath.move(to: CGPoint(x: 82, y: 25))
        bodyPath.addCurve(to: CGPoint(x: 128, y: 84), control1: CGPoint(x: 128, y: 20), control2: CGPoint(x: 143, y: 58))
        bodyPath.addCurve(to: CGPoint(x: 96, y: 157), control1: CGPoint(x: 123, y: 133), control2: CGPoint(x: 112, y: 155))
        bodyPath.addCurve(to: CGPoint(x: 35, y: 107), control1: CGPoint(x: 63, y: 160), control2: CGPoint(x: 26, y: 142))
        bodyPath.addCurve(to: CGPoint(x: 82, y: 25), control1: CGPoint(x: 22, y: 60), control2: CGPoint(x: 42, y: 31))
        context.fill(bodyPath, with: .color(avocado))
        context.stroke(bodyPath, with: .color(ink.opacity(0.18)), lineWidth: 2)

        var fleshPath = Path()
        fleshPath.move(to: CGPoint(x: 83, y: 38))
        fleshPath.addCurve(to: CGPoint(x: 116, y: 88), control1: CGPoint(x: 122, y: 37), control2: CGPoint(x: 132, y: 66))
        fleshPath.addCurve(to: CGPoint(x: 92, y: 145), control1: CGPoint(x: 113, y: 126), control2: CGPoint(x: 105, y: 143))
        fleshPath.addCurve(to: CGPoint(x: 48, y: 105), control1: CGPoint(x: 66, y: 147), control2: CGPoint(x: 40, y: 130))
        fleshPath.addCurve(to: CGPoint(x: 83, y: 38), control1: CGPoint(x: 37, y: 63), control2: CGPoint(x: 54, y: 43))
        context.fill(fleshPath, with: .color(flesh))

        context.fill(Path(ellipseIn: CGRect(x: 66, y: 91, width: 37, height: 42)), with: .color(pit))
        context.fill(Path(ellipseIn: CGRect(x: 74, y: 99, width: 9, height: 11)), with: .color(Color(red: 0.65, green: 0.44, blue: 0.27)))

        let eyeY: CGFloat = mood == .playbackError ? 76 : 74
        context.fill(Path(ellipseIn: CGRect(x: 65, y: eyeY, width: 8, height: 11)), with: .color(ink))
        context.fill(Path(ellipseIn: CGRect(x: 91, y: eyeY - 2, width: 8, height: 11)), with: .color(ink))
        let pupilShift: CGFloat = lookingRight ? 2.5 : 0
        context.fill(Path(ellipseIn: CGRect(x: 69 + pupilShift, y: eyeY + 2, width: 3, height: 4)), with: .color(.white))
        context.fill(Path(ellipseIn: CGRect(x: 95 + pupilShift, y: eyeY, width: 3, height: 4)), with: .color(.white))

        var mouth = Path()
        mouth.move(to: CGPoint(x: 78, y: 91))
        mouth.addQuadCurve(to: CGPoint(x: 88, y: 91), control: CGPoint(x: 83, y: 96))
        context.stroke(mouth, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        var legs = Path()
        legs.move(to: CGPoint(x: 66, y: 151))
        legs.addLine(to: CGPoint(x: 61, y: 164))
        legs.move(to: CGPoint(x: 99, y: 150))
        legs.addLine(to: CGPoint(x: 107, y: 162))
        context.stroke(legs, with: .color(avocado), style: StrokeStyle(lineWidth: 6, lineCap: .round))
    }

    private func drawToaster(in context: inout GraphicsContext) {
        let shell = RoundedRectangle(cornerRadius: 18).path(in: CGRect(x: 137, y: 69, width: 86, height: 82))
        context.fill(shell, with: .color(toaster))
        context.stroke(shell, with: .color(ink.opacity(0.35)), lineWidth: 2)
        let slot = RoundedRectangle(cornerRadius: 6).path(in: CGRect(x: 151, y: 61, width: 58, height: 13))
        context.fill(slot, with: .color(ink.opacity(0.65)))
        context.fill(Path(ellipseIn: CGRect(x: 207, y: 91, width: 8, height: 8)), with: .color(Color(red: 0.88, green: 0.52, blue: 0.24)))
        for x in [155.0, 172.0, 189.0, 206.0] {
            var bar = Path()
            bar.move(to: CGPoint(x: x, y: 80))
            bar.addLine(to: CGPoint(x: x, y: 142))
            context.stroke(bar, with: .color(Color(red: 0.48, green: 0.46, blue: 0.42)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        context.fill(Path(ellipseIn: CGRect(x: 163, y: 154, width: 8, height: 5)), with: .color(ink.opacity(0.2)))
        context.fill(Path(ellipseIn: CGRect(x: 193, y: 154, width: 8, height: 5)), with: .color(ink.opacity(0.2)))
    }

    private func drawLongingArms(in context: inout GraphicsContext) {
        var arms = Path()
        arms.move(to: CGPoint(x: 112, y: 100))
        arms.addQuadCurve(to: CGPoint(x: 145, y: 103), control: CGPoint(x: 131, y: 93))
        arms.move(to: CGPoint(x: 109, y: 119))
        arms.addQuadCurve(to: CGPoint(x: 145, y: 125), control: CGPoint(x: 129, y: 130))
        context.stroke(arms, with: .color(avocado), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: 139, y: 96, width: 13, height: 13)), with: .color(flesh))
        context.fill(Path(ellipseIn: CGRect(x: 139, y: 119, width: 13, height: 13)), with: .color(flesh))
        context.fill(Path(ellipseIn: CGRect(x: 55, y: 58, width: 4, height: 4)), with: .color(.white.opacity(0.8)))
    }

    private func drawMagnifyingGlass(in context: inout GraphicsContext) {
        context.stroke(Path(ellipseIn: CGRect(x: 148, y: 35, width: 55, height: 55)), with: .color(toaster), lineWidth: 8)
        var handle = Path()
        handle.move(to: CGPoint(x: 190, y: 81))
        handle.addLine(to: CGPoint(x: 218, y: 110))
        context.stroke(handle, with: .color(toaster), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        context.stroke(Path(ellipseIn: CGRect(x: 154, y: 41, width: 43, height: 43)), with: .color(.white.opacity(0.5)), lineWidth: 2)
    }

    private func drawQuestionMark(in context: inout GraphicsContext) {
        var mark = Path()
        mark.move(to: CGPoint(x: 202, y: 20))
        mark.addCurve(to: CGPoint(x: 216, y: 37), control1: CGPoint(x: 220, y: 16), control2: CGPoint(x: 223, y: 31))
        mark.addCurve(to: CGPoint(x: 207, y: 52), control1: CGPoint(x: 207, y: 43), control2: CGPoint(x: 207, y: 46))
        mark.move(to: CGPoint(x: 207, y: 62))
        mark.addLine(to: CGPoint(x: 207, y: 64))
        context.stroke(mark, with: .color(Color(red: 0.82, green: 0.56, blue: 0.26)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }

    private func drawBrokenNote(in context: inout GraphicsContext) {
        var note = Path()
        note.move(to: CGPoint(x: 164, y: 48))
        note.addLine(to: CGPoint(x: 164, y: 105))
        note.addLine(to: CGPoint(x: 190, y: 98))
        note.addLine(to: CGPoint(x: 190, y: 39))
        note.addLine(to: CGPoint(x: 213, y: 33))
        context.stroke(note, with: .color(Color(red: 0.82, green: 0.56, blue: 0.26)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        context.fill(Path(ellipseIn: CGRect(x: 151, y: 99, width: 18, height: 12)), with: .color(Color(red: 0.82, green: 0.56, blue: 0.26)))
        context.fill(Path(ellipseIn: CGRect(x: 177, y: 92, width: 18, height: 12)), with: .color(Color(red: 0.82, green: 0.56, blue: 0.26)))
        var crack = Path()
        crack.move(to: CGPoint(x: 180, y: 51))
        crack.addLine(to: CGPoint(x: 171, y: 65))
        crack.addLine(to: CGPoint(x: 184, y: 68))
        crack.addLine(to: CGPoint(x: 174, y: 82))
        context.stroke(crack, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    private func drawOopsStars(in context: inout GraphicsContext) {
        for point in [CGPoint(x: 147, y: 28), CGPoint(x: 220, y: 75), CGPoint(x: 139, y: 138)] {
            context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 6, height: 6)), with: .color(Color(red: 0.88, green: 0.65, blue: 0.33)))
        }
    }

    private func drawFolder(in context: inout GraphicsContext) {
        let tab = RoundedRectangle(cornerRadius: 7).path(in: CGRect(x: 137, y: 64, width: 44, height: 19))
        context.fill(tab, with: .color(Color(red: 0.83, green: 0.62, blue: 0.32)))
        let folder = RoundedRectangle(cornerRadius: 13).path(in: CGRect(x: 132, y: 76, width: 91, height: 66))
        context.fill(folder, with: .color(Color(red: 0.89, green: 0.72, blue: 0.43)))
        context.stroke(folder, with: .color(ink.opacity(0.2)), lineWidth: 2)
    }

    private func drawMusicNotes(in context: inout GraphicsContext) {
        for (x, y) in [(184.0, 39.0), (211.0, 24.0)] {
            var stem = Path()
            stem.move(to: CGPoint(x: x + 10, y: y + 4))
            stem.addLine(to: CGPoint(x: x + 10, y: y + 26))
            stem.addLine(to: CGPoint(x: x + 21, y: y + 23))
            context.stroke(stem, with: .color(avocado), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: x, y: y + 22, width: 12, height: 8)), with: .color(avocado))
        }
    }
}
